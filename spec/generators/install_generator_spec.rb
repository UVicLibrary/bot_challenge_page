# frozen_string_literal: true
require 'rails/generators'
require 'rails'

RSpec.describe("BotChallengePage::InstallGenerator") do
  describe 'installing' do
    let(:dest_root) { Rails.root.join('dummy') }
    let(:initializer_contents) { File.read("#{dest_root}/config/initializers/bot_challenge_page.rb") }
    let(:routes_contents) {File.read("#{dest_root}/config/routes.rb") }
    
    def reset_initializer_content
      File.open("#{dest_root}/config/initializers/bot_challenge_page.rb","w+") do |file|
        file.write(initializer_contents)
      end
    end
    
    def reset_routes
      File.open("#{dest_root}/config/routes.rb","w+") do |file|
        file.write(routes_contents)
      end
    end
    
    before do
      allow(Rails).to receive(:root).and_return(Pathname.new(File.expand_path('../..', __FILE__)))
      initializer_contents
      routes_contents
      # Mute the logging to stdout
      allow_any_instance_of(Thor::Shell::Basic).to receive(:say_status)
    end
    
    context 'without altcha' do
      it "injects content and copies initializer" do
        Rails::Generators.invoke('bot_challenge_page:install',["-f"], destination_root: dest_root)
        expect(File.read("#{dest_root}/config/routes.rb"))
          .to include("bot_challenge_page/altcha_challenge#verify_challenge",
                      "bot_challenge_page#verify_challenge")
        expect(File.read("#{dest_root}/app/controllers/application_controller.rb"))
          .to include("  include BotChallengePage::Controller\n")
        expect(File.exist?("#{dest_root}/config/initializers/bot_challenge_page.rb")).to be true
        expect(File.read("#{dest_root}/config/initializers/bot_challenge_page.rb")).not_to include("altcha")
      end
      
      after do
        Rails::Generators.invoke('bot_challenge_page:install',[], destination_root: dest_root,
                                 behavior: :revoke)
        reset_initializer_content
        reset_routes
      end
    end
    
    context 'with altcha' do
      let(:copy_path) { Rails.root.join("dummy","tmp") }

      it "injects content and copies initializer" do
        Rails::Generators.invoke('bot_challenge_page:install',["--altcha","--altcha_copy_path=tmp","-f"], 
                                 destination_root: dest_root)
        expect(File.read("#{dest_root}/config/routes.rb"))
          .to include("bot_challenge_page/altcha_challenge#verify_challenge",
                      "bot_challenge_page#verify_challenge")
        expect(File.read("#{dest_root}/app/controllers/application_controller.rb"))
          .to include("  include BotChallengePage::Controller\n")
        expect(File.exist?("#{dest_root}/config/initializers/bot_challenge_page.rb")).to be true
      end
      
      it "copies the altcha files" do
        expect {
          Rails::Generators.invoke('bot_challenge_page:install', 
                                   ["--altcha","--altcha_copy_path=tmp","-f"], 
                                   destination_root: dest_root)
        }.to change { Dir.glob("#{copy_path}/altcha/*").map { |file_path| File.basename(file_path) } }
               .from([])
               .to(["altcha.css", "altcha.js", "workers"])
      end
      
      it "sets the right settings in the initializer" do
        Rails::Generators.invoke('bot_challenge_page:install', ["--altcha","--altcha_copy_path=tmp","-f"],
                                 destination_root: dest_root)
        contents = File.read("#{dest_root}/config/initializers/bot_challenge_page.rb")
        expect(contents).to include("config.challenge_provider = \"altcha\"")
        expect(contents).to include("config.altcha_challenge_options")
        expect(contents).to include("render 'bot_challenge_page/bot_challenge_page/altcha_challenge'")
      end

      after do
        Rails::Generators.invoke('bot_challenge_page:install', ["--altcha","--altcha_copy_path=tmp"],
                                 destination_root: dest_root, behavior: :revoke)
        reset_initializer_content
        reset_routes
      end
    end

  end
end