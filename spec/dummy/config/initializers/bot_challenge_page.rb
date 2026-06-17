BotChallengePage.configure do |config|
  config.enabled = true

  # Get from CloudFlare Turnstile: https://www.cloudflare.com/application-services/products/turnstile/
  config.cf_turnstile_sitekey = "1x00000000000000000000AA"
  config.cf_turnstile_secret_key = "1x0000000000000000000000000000000AA"

  # Uncomment to replace Cloudflare widget with Altcha widget
  # config.challenge_provider = "altcha"

  # Uncomment to replace Cloudflare widget with Altcha widget
  # config.challenge_renderer = ->() {
  #   render 'bot_challenge_page/bot_challenge_page/altcha_challenge'
  # }
  
  # Default Altcha challenge settings
  # config.altcha_challenge_options = {
  #   algorithm: "PBKDF2/SHA-256",
  #   cost: 5000,
  #   # Omit counter to run in probabilistic mode: faster challenge generation,
  #   # at the cost of slower verification and less predictable time-to-solve
  #   counter: 5_000,
  #   hmac_signature_secret: ENV.fetch('ALTCHA_HMAC_SECRET', 'change-me-in-production'),
  #   hmac_key_signature_secret: ENV.fetch('ALTCHA_HMAC_KEY_SECRET','change-me-in-production'),
  #   expires_at: 5.minutes, # How long a challenge stays valid before it expires
  #   cache_expires_at: 1.hour, # How long to cache solved challenges to prevent replay attacks
  #   # (https://altcha.org/docs/v2/security-recommendations/#replay-attacks)
  #   theme: "default"
  # }
  
  # How long will a challenge success exempt a session from further challenges?
  # BotChallengePage.config.session_passed_good_for = 36.hours

  # More configuration is available
end
