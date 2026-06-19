require 'http'

# This controller has actions for issuing a challenge page for CloudFlare Turnstile product,
# and then redirecting back to desired page.
#
# It also includes logic for configuring rack attack and a Rails controller filter to enforce
# redirection to these actions. All the logic related to bot detection with turnstile is
# mostly in this file -- with very flexible configuration in class_attributes -- to faciliate
# future extraction to a re-usable gem if desired.
#
#
module BotChallengePage
  class BotChallengePageController < ::ApplicationController
    include BotChallengePage::GuardAction

    # We access all config at the controller level, intending to support
    # a design of different controllers in the same app with different config, protecting
    # different parts of your app.
    #
    # But most people won't use that, just default to a global config for simplicity.
    class_attribute :bot_challenge_config, default: ::BotChallengePage.config

    SESSION_DATETIME_KEY = "t"
    SESSION_FINGERPRINT_KEY = "f"

    # only used if config.redirect_for_challenge is true
    def challenge
      # possible custom render to choose layouts or templates, but
      # default is what would be default template for this action
      #
      # We put it in instancevar as a hacky way of passing to template that can be fulfilled
      # both here and in arbitrary controllers for direct render.
      @bot_challenge_config = bot_challenge_config
      instance_exec &self.bot_challenge_config.challenge_renderer
    end

    def verify_challenge
      @result = verify_cloudflare
      if @result.verified
        after_challenge_success(@result)
      else
        after_challenge_failure(@result)
      end
    end

    private

    # This only runs for a successful page/JSON challenge (NOT a form!)
    def after_challenge_success(result)
      attach_session_cookie
      # add config needed by JS to result
      result.result["redirect_for_challenge"] = self.bot_challenge_config.redirect_for_challenge
      # and let's just return the whole thing to client? Is there anything confidential there?
      render json: result.result
    end

    def attach_session_cookie
      session[self.bot_challenge_config.session_passed_key] = {
        ::BotChallengePage::BotChallengePageController::SESSION_DATETIME_KEY => Time.now.utc.iso8601,
        ::BotChallengePage::BotChallengePageController::SESSION_FINGERPRINT_KEY   => self.bot_challenge_config.session_valid_fingerprint.call(request)
      }
    end

    module Verification
      extend ActiveSupport::Concern

      private

      def verify_cloudflare
        body = {
          secret: self.bot_challenge_config.cf_turnstile_secret_key,
          response: params["cf_turnstile_response"],
          remoteip: request.remote_ip,
        }

        http = HTTP.timeout(self.bot_challenge_config.cf_timeout)
        response = http.post(self.bot_challenge_config.cf_turnstile_validation_url,
                             json: body)
        # {"success"=>true, "error-codes"=>[], "challenge_ts"=>"2025-01-06T17:44:28.544Z", "hostname"=>"example.com", "metadata"=>{"result_with_testing_key"=>true}}
        # {"success"=>false, "error-codes"=>["invalid-input-response"], "messages"=>[], "metadata"=>{"result_with_testing_key"=>true}}
        Result.new(response.parse)
      rescue HTTP::Error, JSON::ParserError => error
        after_verify_error(error)
      end

      def after_challenge_failure(result)
        logger = self.bot_challenge_config.challenge_logger || Rails.logger
        logger.warn(
          "#{self.class.name}: #{self.bot_challenge_config.challenge_provider.titleize} " +
            "validation failed: #{result.inspect}" +
            "Request from: #{request.remote_ip}, #{request.user_agent}"
        )
        # add config needed by JS to result
        result.result["redirect_for_challenge"] = self.bot_challenge_config.redirect_for_challenge
        # and let's just return the whole thing to client? Is there anything confidential there?
        render json: result.result
      end

      # This runs after an internal server error
      def after_verify_error(error)
        Rails.logger.error "#{e.class} (#{e.message}):\n" + e.backtrace.join("\n")
        # Also log it to the challenge/validation logger if it's not Rails.logger
        if self.bot_challenge_config.challenge_logger
          self.bot_challenge_config.challenge_logger.warn(
            "#{self.class.name}: #{self.bot_challenge_config.challenge_provider.titleize} " +
              "validation failed due to server error: #{error.message}. " +
              "Request from: #{request.remote_ip}, #{request.user_agent}"
          )
        end
        render json: { success: false, message: t('bot_challenge_page.error'), status: 500 }
      end

      # A light wrapper class to allow result to respond to :error_message
      class Result
        
        # @param Hash
        def initialize(result)
          @result = result
        end
        attr_reader :result
        
        def verified
          result['success']
        end
        
        def error_message
          I18n.t('bot_challenge_page.error')
        end
        
      end
    end
    include Verification
  end
end
