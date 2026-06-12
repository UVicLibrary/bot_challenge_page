module BotChallengePage
  class InstallGenerator < Rails::Generators::Base
    source_root File.expand_path("templates", __dir__)

    class_option :'rack_attack', type: :boolean, default: true, desc: "Support rate-limit allowance configuration"
    class_option :redirect_for_challenge, type: :boolean, default: false, desc: "Redirect to separate challenge page instead of inline challenge"
    class_option :altcha, type: :boolean, default: false, desc: "Use ALTCHA (altcha.org) as the challenge/widget provider"
    class_option :altcha_copy_path, type: :string, default: "#{File.expand_path('../..', __FILE__)}/public", desc: "(Optional) The path to copy ALTCHA JS/CSS files to. By default, this is your app's public folder."

    def generate_routes
      route 'post "/challenge", to: "bot_challenge_page/bot_challenge_page#verify_challenge", as: :bot_detect_challenge'
      route 'post "/altcha_challenge", to: "bot_challenge_page/altcha_challenge#verify_challenge", as: :altcha_bot_challenge'
      
      if options[:redirect_for_challenge]
        route 'get "/challenge", to: "bot_challenge_page/bot_challenge_page#challenge"'
      end
    end

    def add_controller_mixin
      inject_into_class "app/controllers/application_controller.rb", "ApplicationController", "  include BotChallengePage::Controller\n"
    end

    def copy_initializer_file
      template "initializer.rb.erb", "config/initializers/bot_challenge_page.rb"
    end
    
    def copy_altcha_files
      if options[:altcha]
        path = Pathname.new(options[:altcha_copy_path])
        altcha_dir = path.join("altcha")
        directory("altcha", altcha_dir)
        message = "Altcha files copied to #{path.to_s}."
        if path != "#{File.expand_path('../..', __FILE__)}/public"
          message += " Please override views/bot_challenge_page/altcha/altcha_widget.html.erb with the correct path to the correct JS/CSS"
        end
        return unless behavior == :revoke
        FileUtils.rm_rf(Pathname.new(destination_root).join(altcha_dir))
        say_status :remove, altcha_dir, :red
      end
    end
  end
end
