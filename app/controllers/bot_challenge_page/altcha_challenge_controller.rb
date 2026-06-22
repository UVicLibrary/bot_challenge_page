module BotChallengePage
  class AltchaChallengeController < BotChallengePageController
    
    def verify_challenge
      altcha_params
      @result = verify_altcha
      if @result.verified
        after_challenge_success(@result)
      else
        after_challenge_failure(@result)
      end
    end

    # This only runs for a successful page/JSON challenge (NOT a form!)
    def after_challenge_success(result)
      attach_session_cookie
      response = { success: true }
      response[:redirect_for_challenge] = true if self.bot_challenge_config.redirect_for_challenge
      render json: response, success: true, status: 200
    end
    
    module Verification
      extend ActiveSupport::Concern
      
      included do
        class_attribute :cache_key_prefix
        self.cache_key_prefix = "altcha-v2"
      end
      
      private

      def altcha_params
        params.permit(:altcha)
      end
      
      # @return [Altcha::V2::VerifySolutionResult] - a class from the altcha-lib gem
      def verify_altcha
        config = self.bot_challenge_config.altcha_challenge_options
        begin
          decoded = JSON.parse(Base64.decode64(params[:altcha]))
          result = if decoded.key?('verificationData')
                     Altcha::V2.verify_server_signature(
                       payload:     Altcha::V2::ServerSignaturePayload.from_h(decoded),
                       hmac_secret: config[:hmac_signature_secret]
                     )
                   else
                     payload = Altcha::V2::Payload.new(
                       challenge: Altcha::V2::Challenge.from_h(decoded['challenge']),
                       solution:  Altcha::V2::Solution.new(
                         counter:     decoded['solution']['counter'],
                         derived_key: decoded['solution']['derivedKey']
                       )
                     )
                     Altcha::V2.verify_solution(
                       payload.challenge,
                       payload.solution,
                       hmac_signature_secret:     config[:hmac_signature_secret],
                       hmac_key_signature_secret: config[:hmac_signature_key_secret]
                     )
                   end
          Result.new(result, replay_attack?)
        rescue JSON::ParserError,NoMethodError => _error
         Result.new(params[:altcha], false)
        end
      end

      def after_challenge_failure(result)
        if self.bot_challenge_config.challenge_provider == "altcha"
          logger = self.bot_challenge_config.challenge_logger || Rails.logger
          logger.warn(
            "#{DateTime.now}  " + 
            "#{self.class.name}: #{self.bot_challenge_config.challenge_provider.capitalize} " +
              "validation failed: #{result.inspect}" +
              "Request from: #{request.remote_ip}, #{request.user_agent}"
          )
          render json: { message: result.error_message }, status: 400, success: false
        else
          # Call super here because this module is included in form validation
          # (controllers/concerns/bot_challenge_page/guard_form), and we want to 
          # use the Cloudflare method instead if that's configured
          super
        end
      end
      
      # https://altcha.org/docs/v2/security-recommendations/#replay-attacks
      def replay_attack?
        cache_store = self.bot_challenge_config.store || self.cache_store
        cache_key = JSON.parse(Base64.decode64(params[:altcha]))['challenge']['signature']
        return true if cache_store.exist?("#{self.cache_key_prefix}_#{cache_key}")
        
        expires_at = self.bot_challenge_config.altcha_challenge_options.fetch(:cache_expires_at)
        cache_store.fetch("#{self.cache_key_prefix}_#{cache_key}", expires_at: Time.now + expires_at) do
          # Doesn't really matter what we put here?
          params[:altcha]
        end
        false
      end

      # A light wrapper class to allow result to respond to :error_message
      class Result
        
        # @param Altcha::V2::VerifySolutionResult
        def initialize(result, replay_attack)
          @result = result.tap { |result| result.verified = false if replay_attack }
          @replay_attack = replay_attack
        end
        attr_reader :result, :replay_attack
        
        # Make some methods available as a courtesy for downstream apps
        # even if we don't use all these options ourselves
        delegate :verified=, :expired, :invalid_signature, to: :result
        
        def verified
          result.respond_to?(:verified) ? result.verified : false
        end

        def error_message
          if result.is_a? String # result of a JSON::ParserError
            I18n.t('bot_challenge_page.altcha_error.incorrect_solution')
          elsif result.expired
            I18n.t('bot_challenge_page.altcha_error.expired')
          elsif result.invalid_signature
            I18n.t('bot_challenge_page.altcha_error.invalid_signature')
          elsif replay_attack
            I18n.t('bot_challenge_page.altcha_error.replay_attack')
          else
            I18n.t('bot_challenge_page.altcha_error.incorrect_solution')
          end
        end
      end
    end
    include Verification
  end
end