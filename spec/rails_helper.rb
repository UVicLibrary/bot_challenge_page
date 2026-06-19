# This file is copied to spec/ when you run 'rails generate rspec:install'
require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'

require_relative "../spec/dummy/config/environment"

# Prevent database truncation if the environment is production
abort("The Rails environment is running in production mode!") if Rails.env.production?
# Uncomment the line below in case you have `--require rails_helper` in the `.rspec` file
# that will avoid rails generators crashing because migrations haven't been run yet
# return unless Rails.env.test?
require 'rspec/rails'
# Add additional requires below this line. Rails is not loaded until this point!


ActiveRecord::Migrator.migrations_paths = [ File.expand_path("../spec/dummy/db/migrate", __dir__) ]

# Requires supporting ruby files with custom matchers and macros, etc, in
# spec/support/ and its subdirectories. Files matching `spec/**/*_spec.rb` are
# run as spec files by default. This means that files in spec/support that end
# in _spec.rb will both be required and run as specs, causing the specs to be
# run twice. It is recommended that you do not name files matching this glob to
# end with _spec.rb. You can configure this pattern with the --pattern
# option on the command line or in ~/.rspec, .rspec or `.rspec-local`.
#
# The following line is provided for convenience purposes. It has the downside
# of increasing the boot-up time by auto-requiring all files in the support
# directory. Alternatively, in the individual `*_spec.rb` files, manually
# require only the support files necessary.
#

BotChallengePage::Engine.root.glob('spec/support/helpers/**/*.rb').sort_by(&:to_s).each { |f| require f }

# Checks for pending migrations and applies them before tests are run.
# If you are not using ActiveRecord, you can remove these lines.
begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end
RSpec.configure do |config|
  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  config.fixture_paths = [
    Rails.root.join('spec/fixtures')
  ]

  config.include BotChallengeConfigHelper

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  config.use_transactional_fixtures = true

  # Capyabara.javascript_driver setting directly applies to 'feature' spec
  Capybara.default_driver = :rack_test # Faster but doesn't do Javascript
  Capybara.javascript_driver = ENV['SHOW_BROWSER'] ? :selenium_chrome : :selenium_chrome_headless
  Capybara.javascript_driver = :selenium_chrome

  # You can uncomment this line to turn off ActiveRecord support entirely.
  # config.use_active_record = false

  # RSpec Rails uses metadata to mix in different behaviours to your tests,
  # for example enabling you to call `get` and `post` in request specs. e.g.:
  #
  #     RSpec.describe UsersController, type: :request do
  #       # ...
  #     end
  #
  # The different available types are documented in the features, such as in
  # https://rspec.info/features/7-1/rspec-rails
  #
  # You can also this infer these behaviours automatically by location, e.g.
  # /spec/models would pull in the same behaviour as `type: :model` but this
  # behaviour is considered legacy and will be removed in a future version.
  #
  # To enable this behaviour uncomment the line below.
  # config.infer_spec_type_from_file_location!

  # Filter lines from Rails gems in backtraces.
  # config.filter_rails_from_backtrace!
  # arbitrary gems may also be filtered via:
  # config.filter_gems_from_backtrace("gem name")

  config.around(:example, provider: :altcha) do |example|
    controller = example.metadata[:controller] || BotChallengePage::AltchaChallengeController
    options = example.metadata[:options] || {}
    original_config = controller.bot_challenge_config.dup
    
    altcha_options = {
      enabled: true,
      challenge_provider: "altcha",
      challenge_renderer: ->() {
        render 'bot_challenge_page/bot_challenge_page/altcha_challenge'
      }
    }
    set_config(controller, **altcha_options.merge(options))
    example.run
    reset_config(controller, original_config)
  end

  config.around(:example, provider: :cloudflare_turnstile) do |example|
    controller = example.metadata[:controller] || BotChallengePage::BotChallengePageController
    options = example.metadata[:options] || {}
    original_config = controller.bot_challenge_config.dup

    cf_turnstile_sitekey = options.fetch(:cf_turnstile_sitekey, "1x00000000000000000000AA")
    cf_turnstile_secret_key = if options.fetch(:cf_turnstile_secret_key, nil)
                                options.fetch(:cf_turnstile_secret_key)
                              else
                                # Set challenge to passing by default
                                if example.metadata[:passing] == false
                                  "2x0000000000000000000000000000000AA"
                                else
                                  "1x0000000000000000000000000000000AA"
                                end
                              end
    cloudflare_options = {
      enabled: true,
      cf_turnstile_sitekey: cf_turnstile_sitekey,
      cf_turnstile_secret_key:  cf_turnstile_secret_key,
      challenge_provider: "cloudflare_turnstile",
      challenge_renderer: lambda { render "bot_challenge_page/bot_challenge_page/challenge", status: 403 }
    }
    set_config(controller, **cloudflare_options.merge(options))
    example.run
    reset_config(controller, original_config)
  end
end




# Trying to fix
# https://github.com/teamcapybara/capybara/issues/2800

if (Rails.env.test? || (defined?(Capybara::Node::Base) && defined?(Selenium::WebDriver::Error::UnknownError)))
  unless Capybara::Node::Base.instance_methods.include?(:catch_error?)
    raise "Could not patch Capybara::Node::Base#catch_error? becuase it did not exist! Trying to patch for https://github.com/teamcapybara/capybara/issues/2800"
  end

  Capybara::Node::Base.prepend(Module.new do
    protected

    # https://github.com/teamcapybara/capybara/blob/0480f90168a40780d1398c75031a255c1819dce8/lib/capybara/node/base.rb#L134C10-L137
    #
    # and see
    #
    # https://github.com/teamcapybara/capybara/blob/0480f90168a40780d1398c75031a255c1819dce8/lib/capybara/node/base.rb#L85-L99
    def catch_error?(error, *args)
      super || (error.kind_of?(Selenium::WebDriver::Error::UnknownError) && error.message.include?("Node with given id does not belong to the document"))
    end
  end)
end
