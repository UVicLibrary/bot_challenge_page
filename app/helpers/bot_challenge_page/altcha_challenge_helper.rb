module BotChallengePage
  module AltchaChallengeHelper
    
    def challenge_options
      # Filter out any config keys that are not used by the altcha-lib challenge interface
      valid_options = Altcha::V2::CreateChallengeOptions.instance_method(:initialize).parameters.map(&:second)
      Altcha::V2::CreateChallengeOptions.new(
        **altcha_config.select { |key,_val| valid_options.include? key }
                       .merge(expires_at: Time.now + altcha_config.fetch(:expires_at).seconds.to_i))
    end
    
    def altcha_config
      @bot_challenge_config.try(:altcha_challenge_options) || controller.class.bot_challenge_config.altcha_challenge_options
    end
    
  end
end