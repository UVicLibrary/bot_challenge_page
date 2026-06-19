module BotChallengeConfigHelper
  def with_bot_challenge_config(controller, **args)
    @orig_config = controller.bot_challenge_config.dup
    set_config(controller, args)
    yield
    reset_config(controller)
  end
  
  def set_config(controller, args)
    args.each_pair do |key, value|
      controller.bot_challenge_config.send("#{key}=", value)
    end
  end
  
  def reset_config(controller, orig_config = @orig_config)
    controller.bot_challenge_config = orig_config
    # We also need to reset any ancestor classes (up to ApplicationController)
    # to avoid errors when running specs in a specific order
    controller.ancestors.select { |ancestor| ancestor.class == Class }.each do |klass|
      klass.bot_challenge_config = orig_config if klass.respond_to?(:bot_challenge_config)
      # Don't need to go any deeper than ApplicationController because that would 
      # get into irrelevant rails stuff
      break if klass == ApplicationController
    end
  end
end
