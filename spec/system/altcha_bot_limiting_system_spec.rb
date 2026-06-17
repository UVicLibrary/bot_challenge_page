require 'rails_helper'
require 'altcha'

# We're just testing displaying the challenge here, since Altcha seems
# to block Capybara/Selenium from checking the box for testing...
# which is probably a good thing overall!

# Testing the challenge creation/solution is done in requests/altcha_challenge_request_spec.

describe "Displaying altcha challenge", type: :system do
  
  before do
    WebMock.allow_net_connect!
    # not sure why this breaks it, but it seems to be memory store by default, fine.
    #ActionController::Base.cache_store = :memory_store
  end

  # Temporarily change desired mocked config
  # Kinda hacky because we need to keep re-registering the tracks
  around(:each) do |example|
    with_bot_challenge_config(BotChallengePage::AltchaChallengeController,
                              enabled: true,
                              challenge_provider: "altcha",
                              challenge_renderer: ->() {
                                render 'bot_challenge_page/bot_challenge_page/altcha_challenge'
                              }
                             ) { example.run }
  end

  describe "limiting after 1 request" do

    before do
      allow(Rails.logger).to receive(:info)
    end

    it "displays the challenge and altcha widget" do
      visit altcha_dummy_rate_limit_1_path
      expect(page).to have_content(/rendered #rate_limit_1/)
      # on second try, we're gonna get a challenge page instead
      visit altcha_dummy_rate_limit_1_path
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
