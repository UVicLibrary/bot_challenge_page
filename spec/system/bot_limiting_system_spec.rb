require 'rails_helper'

include WebmockTurnstileHelperMethods

describe "Bot limiting", type: :system do
  
  before do
    allow(Rails.logger).to receive(:info)
  end

  context 'using Cloudflare Turnstile' do

    describe "succesful challenge" do
      
      # Temporarily change desired mocked config
      # Kinda hacky because we need to keep re-registering the tracks
      around(:each) do |example|
        with_cloudflare_challenge_config(BotChallengePage::BotChallengePageController) { example.run }
      end
      
      before do
        stub_turnstile_success(request_body: {
          "secret"=>BotChallengePage::BotChallengePageController.bot_challenge_config.cf_turnstile_secret_key,
          "response"=>"XXXX.DUMMY.TOKEN.XXXX", "remoteip"=>"127.0.0.1"
        })
      end

      it "smoke tests" do
        visit dummy_rate_limit_1_path
        expect(page).to have_content(/rendered #rate_limit_1/)
        # on second try, we're gonna get a challenge page instead
        visit dummy_rate_limit_1_path
        expect(page).to have_content(I18n.t("bot_challenge_page.title"))

        # which eventually will reload and display original desired page page
        expect(page).to have_content(/rendered #rate_limit_1/, wait: 7)
      end

      describe "with redirect_for_challenge" do
        around do |example|
          with_cloudflare_challenge_config(BotChallengePage::BotChallengePageController,
                                           redirect_for_challenge: true
          ) { example.run }
        end

        it "smoke tests" do
          visit dummy_rate_limit_1_path
          expect(page).to have_content(/rendered #rate_limit_1/)

          # on second try, we're gonna get redirected to bot check page
          visit dummy_rate_limit_1_path
          expect(page).to have_content(I18n.t("bot_challenge_page.title"))

          # which eventually will redirect back to original page
          expect(page).to have_content(/rendered #rate_limit_1/, wait: 7)
        end
      end
    end

    describe "failed challenge" do

      around(:each) do |example|
        with_cloudflare_challenge_config(BotChallengePage::BotChallengePageController, passing: false) { example.run }
      end

      before do
        allow(Rails.logger).to receive(:warn)
        stub_turnstile_failure(request_body: {
          "secret"=>BotChallengePage::BotChallengePageController.bot_challenge_config.cf_turnstile_secret_key,
          "response"=>"XXXX.DUMMY.TOKEN.XXXX", "remoteip"=>"127.0.0.1"
        })
      end

      it "stays on page with failure" do
        visit dummy_rate_limit_1_path
        expect(page).to have_content(/rendered #rate_limit_1/)

        # on second try, we're gonna get redirected to bot check page
        visit dummy_rate_limit_1_path
        expect(page).to have_content(I18n.t("bot_challenge_page.title"))

        # which is going to get a failure message
        expect(page).to have_content(I18n.t("bot_challenge_page.error"), wait: 7)
        expect(Rails.logger).to have_received(:warn).with(/BotChallengePage::BotChallengePageController: Cloudflare Turnstile validation failed/)
      end
    end
  end
  
  context 'using Altcha' do
    # We're just testing displaying the challenge here, since Altcha seems
    # to block Capybara/Selenium from checking the box for testing...
    # which is probably a good thing overall!
    
    # Testing the challenge creation/solution happens in requests/altcha_challenge_request_spec.
    
    around(:each) do |example|
      with_altcha_challenge_config(BotChallengePage::BotChallengePageController) { example.run }
    end

    describe "limiting after 1 request" do

      it "displays the challenge and altcha widget" do
        visit dummy_rate_limit_1_path
        expect(page).to have_content(/rendered #rate_limit_1/)
        # on second try, we're gonna get a challenge page instead
        visit dummy_rate_limit_1_path
        expect(page).to have_content(I18n.t("bot_challenge_page.title"))
        expect(find('altcha-widget')).to have_text("I'm not a robot")
      end
    end

    describe "with redirect_for_challenge" do

      it "displays the challenge and altcha widget" do
        # our destination is a forced download, so they never naviagate anywhere else
        visit "/challenge?dest=#{dummy_download_path}"

        expect(page).to have_content(I18n.t("bot_challenge_page.title"))
        expect(find('altcha-widget')).to have_text("I'm not a robot")
      end
    end
  end
  
  before do
    # not sure why this breaks it, but it seems to be memory store by default, fine.
    #ActionController::Base.cache_store = :memory_store
    ActionController::Base.cache_store.clear
  end
end