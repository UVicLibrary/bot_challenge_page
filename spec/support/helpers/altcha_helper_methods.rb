# frozen_string_literal: true
module AltchaHelperMethods
  
  # @return Altcha::V2::Challenge
  def stub_altcha_challenge(expires_at: Time.now + altcha_config.fetch(:expires_at).seconds.to_i)
    valid_options = Altcha::V2::CreateChallengeOptions.instance_method(:initialize).parameters.map(&:second)
    options = Altcha::V2::CreateChallengeOptions.new(
      **altcha_config.select { |key,_val| valid_options.include? key }
                     .merge(expires_at: expires_at))
    Altcha::V2.create_challenge(options)
  end
  
  # @return Hash
  def stub_altcha_config
    # Use very lightweight challenge options to speed up testing
    BotChallengePage::AltchaChallengeController.new
                                               .bot_challenge_config
                                               .altcha_challenge_options
                                               .merge({
                                                        algorithm: "PBKDF2/SHA-256",
                                                        cost: 10,
                                                        counter: 1
                                                      })
  end
  
end