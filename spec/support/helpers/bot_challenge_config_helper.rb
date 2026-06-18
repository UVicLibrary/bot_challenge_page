module BotChallengeConfigHelper
  def with_bot_challenge_config(controller, **args)
    @orig_config = controller.bot_challenge_config.dup
    set_config(controller, args)
    yield
    reset_config(controller)
  end
  
  def with_cloudflare_challenge_config(controller, passing_secret_key: true, **args)
    @orig_config = controller.bot_challenge_config.dup
    cf_turnstile_sitekey = args.fetch(:cf_turnstile_sitekey, "1x00000000000000000000AA")
    cf_turnstile_secret_key = if args.fetch(:cf_turnstile_secret_key, nil).present?
                                args.fetch(:cf_turnstile_secret_key)
                              else
                                passing_secret_key ? "1x0000000000000000000000000000000AA" : "2x0000000000000000000000000000000AA"
                              end

    set_config(controller, args.merge(
      enabled: true,
      cf_turnstile_sitekey: cf_turnstile_sitekey,
      cf_turnstile_secret_key:  cf_turnstile_secret_key,
      challenge_provider: "cloudflare_turnstile"
    ))
    yield
    reset_config(controller)
  end
  
  def with_altcha_challenge_config(controller, **args)
    @orig_config = controller.bot_challenge_config.dup
    set_config(controller, args.merge(
      enabled: true,
      challenge_provider: "altcha",
      challenge_renderer: ->() {
        render 'bot_challenge_page/bot_challenge_page/altcha_challenge'
      },
      challenge_logger: Rails.logger))
    yield
    reset_config(controller)
  end
  
  private
  
  def set_config(controller, args)
    args.each_pair do |key, value|
      controller.bot_challenge_config.send("#{key}=", value)
    end
  end
  
  def reset_config(controller)
    controller.bot_challenge_config = @orig_config
    # We also need to reset any ancestor classes (up to ApplicationController)
    # to avoid errors when running specs in a specific order
    controller.ancestors.select { |ancestor| ancestor.class == Class }.each do |klass|
      klass.bot_challenge_config = @orig_config if klass.respond_to?(:bot_challenge_config)
      # Don't need to go any deeper than ApplicationController because that would 
      # get into irrelevant rails stuff
      break if klass == ApplicationController
    end
  end
end
