module BotChallengePage
  class AltchaChallengeController < BotChallengePageController
    
    def verify_challenge
      altcha_params
      @result = verify_altcha
      if @result.verified && !replay_attack?
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
          result
        rescue JSON::ParserError,NoMethodError => error
          after_challenge_failure(error)
        rescue RuntimeError => error
          after_verify_error(error)
        end
      end

      def after_challenge_failure(result)
        if self.bot_challenge_config.challenge_provider == "altcha"
          reason = if result.is_a? String
                     # result of a JSON::ParserError
                     'Incorrect solution'
                   elsif result.expired
                     'Challenge expired'
                   elsif result.invalid_signature
                     'Invalid challenge signature'
                   else
                     'Incorrect solution'
                   end
          logger = self.bot_challenge_config.challenge_logger || Rails.logger
          logger.warn(
            "#{self.class.name}: #{self.bot_challenge_config.challenge_provider.capitalize} " +
              "validation failed: #{result.inspect}" +
              "Request from: #{request.remote_ip}, #{request.user_agent}"
          )
          render json: { message: reason }, status: 400, success: false
        else
          # Call super here because this module is included in form validation
          # (controllers/concerns/bot_challenge_page/guard_form), and we want to 
          # use the Cloudflare method instead if that's configured
          super
        end
      end

      # This runs after an internal server error
      def after_verify_error(error)
        Rails.logger.error "#{e.class} (#{e.message}):\n" + e.backtrace.join("\n")
        # Also log it to the challenge/validation logger
        if self.bot_challenge_config.challenge_logger
          self.bot_challenge_config.challenge_logger.warn(
            "#{self.class.name}: Altcha validation failed due to server error: #{error.message}. " +
              "Request from: #{request.remote_ip}, #{request.user_agent}"
          )
        end
        render json: { message: t('bot_challenge_page.error')}, status: 500, success: false
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
    end
    include Verification
  end
  class CacheMissingError < StandardError; end
end