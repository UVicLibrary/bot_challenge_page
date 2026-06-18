module BotChallengePage
  module GuardForm
    extend ActiveSupport::Concern

    include BotChallengePage::BotChallengePageController::Verification
    include BotChallengePage::AltchaChallengeController::Verification

    included do
      # We access all config at the controller level, intending to support
      # a design of different controllers in the same app with different config, protecting
      # different parts of your app.
      #
      # But most people won't use that, just default to a global config for simplicity.
      class_attribute :bot_challenge_config, default: ::BotChallengePage.config
    end

    # Returns nil if the challenge was passed; calls #after_challenge_failure
    # if the challenge was failed. This is intended to be used in a 
    # before hook for a controller, e.g.:
    #
    #  before_action :prepare_challenge, only: :new
    #  before_action :verify_form, only: :create
    #
    #  def after_verify_error(result)
    #    flash[:error] = "Friendly error message"
    #    render :new
    #  end
    #
    # You may also want to override #after_verify_error, which catches StandardError
    def verify_form
      @result = case self.bot_challenge_config.challenge_provider
                when "altcha"
                  verify_altcha
                when "cloudflare_turnstile"
                  verify_cloudflare
                else
                  raise "Challenge provider not recognized. Accepted options are " +
                          "'altcha' or 'cloudflare_turnstile'"
                end
      unless verified?
        # allow app to see and log if desired
        self.instance_exec(self, &self.bot_challenge_config.after_blocked)
        # Override this method in your controller. By default, 
        # this returns a JSON response, which you probably don't want
        after_challenge_failure(@result)
      end
    end
    
    def prepare_challenge
      # Prevent caching, which can break the altcha widget
      self.response.headers["Cache-Control"] = "no-store"

      # hacky way to get config to view template in an arbitrary controller, good enough for now
      self.instance_variable_set("@bot_challenge_config", self.bot_challenge_config) unless self.instance_variable_get("@bot_challenge_config")

      # set preload HTTP header for better page speed
      # May or may not be one there already, we can always add on
      preload_link_value = if self.bot_challenge_config.challenge_provider == "altcha"
                             %Q{<#{self.bot_challenge_config.altcha_js_url}>; rel=preload; as=script; crossOrigin="anonymous"}
                           else
                             %Q{<#{self.bot_challenge_config.cf_turnstile_js_url}>; rel=preload; as=script}
                           end
      if self.headers["link"].present?
        self.headers["link"] += ",#{preload_link_value}"
      else
        self.headers["link"] = "#{preload_link_value}"
      end
    end

    private
    
    def verified?
      if self.bot_challenge_config.challenge_provider == "altcha"
        return false unless @result.is_a?(Altcha::V2::VerifySolutionResult)
        @result.verified && !replay_attack?
      else
        @result['success'].present?
      end
    end
  end
end