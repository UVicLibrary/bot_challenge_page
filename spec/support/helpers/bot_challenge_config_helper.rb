module BotChallengeConfigHelper
  def with_bot_challenge_config(controller, **args)
    orig_config = controller.bot_challenge_config.dup
    args.each_pair do |key, value|
      controller.bot_challenge_config.send("#{key}=", value)
    end
    yield
    controller.bot_challenge_config = orig_config
    
    # We also need to reset any ancestor classes (except ApplicationController)
    # to avoid errors when running specs in a specific order
    controller.ancestors.select { |ancestor| ancestor.class == Class }.each do |klass|
      klass.bot_challenge_config = orig_config if klass.respond_to?(:bot_challenge_config)
      # Don't need to go any deeper than ApplicationController. Otherwise, we 
      # start getting into weird rails stuff
      break if klass == ApplicationController
    end
  end
end
