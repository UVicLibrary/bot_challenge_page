# frozen_string_literal: true
require 'rails_helper'

RSpec.describe "dummy form request", type: :system do
  include WebmockTurnstileHelperMethods
  include AltchaHelperMethods

  before do
    # not sure why this breaks it, but it seems to be memory store by default, fine.
    #ActionController::Base.cache_store = :memory_store
    ActionController::Base.cache_store.clear
  end
  
  context 'with altcha challenge provider', provider: :altcha, controller: DummyFormController do

    describe 'setting up the form' do
      it 'turns caching off and preloads the JS' do
        get '/dummy_form/new'
        expect(response.headers['cache-control']).to eq "no-store"
        expect(response.headers['link']).to match(/rel=preload; as=script;/)
      end

      it 'renders the widget' do
        visit '/dummy_form/new'
        expect(find('altcha-widget')).to have_text("I'm not a robot", wait: 4)
      end
    end

    describe 'submitting the form' do
      let(:challenge) { stub_altcha_challenge }
      let(:altcha_config) { stub_altcha_config }

      let(:solution) do
        Altcha::V2::Payload.new(challenge: challenge, solution: Altcha::V2.solve_challenge(challenge)).to_json
      end
      
      context 'when challenge is successful' do
        it 'renders the submitted data' do
          post '/dummy_form', params: { altcha: Base64.encode64(solution), data: "Some data" }
          expect(response).to be_successful
          expect(response.body).to match("Some data")
        end
      end
      
      context 'when challenge is unsuccessful' do
        before do
          allow_any_instance_of(Altcha::V2::VerifySolutionResult).to receive(:verified).and_return false
          allow_any_instance_of(BotChallengePage::Config).to receive(:after_blocked).and_return(Proc.new {})
        end
        
        it 'calls a customized #after_challenge_failure action' do
          # Soft check that after_blocked proc is called
          expect_any_instance_of(BotChallengePage::Config).to receive(:after_blocked)
          post '/dummy_form', params: { altcha: Base64.encode64(solution), data: "Some data" }
          expect(response.body).to match("Incorrect solution")
        end
      end
    end
  end

  context 'with cloudflare turnstile' do
    
    context 'when challenge is successful', provider: :cloudflare_turnstile, controller: DummyFormController do
      
      let(:cf_turnstile_secret_key) { "1x0000000000000000000000000000000AA" } # a testing key always passes
      
      before do
        allow(Rails.logger).to receive(:info)
        stub_turnstile_success(request_body: {
          "secret"=> cf_turnstile_secret_key,
          "response"=> "",
          "remoteip"=>"127.0.0.1"
        })
      end
      
      it 'turns caching off and preloads the JS' do
        get '/dummy_form/new'
        expect(response.headers['cache-control']).to eq "no-store"
        expect(response.headers['link']).to match(/rel=preload; as=script/)
      end
      
      it 'smoke test' do
        visit new_dummy_form_path
        expect(page).to have_selector("div.cf-turnstile[data-sitekey='1x00000000000000000000AA']")
        fill_in "Data:", with: "Some data"
        find('input[type="submit"]').click
        expect(page).to have_content('Some data')
      end
    end
    
    context 'when challenge is not successful', provider: :cloudflare_turnstile, controller: DummyFormController, 
                                                                                 passing: false do
      # around(:each) do |example|
      #   with_cloudflare_challenge_config(DummyFormController, passing: false) { example.run }
      # end
      
      let(:cf_turnstile_secret_key) { "2x0000000000000000000000000000000AA" } # a testing key that produces failure

      before do
        allow(Rails.logger).to receive(:warn)
        allow_any_instance_of(BotChallengePage::Config).to receive(:after_blocked).and_return(Proc.new {})
        stub_turnstile_failure(request_body: {
          "secret"=>cf_turnstile_secret_key,
          "response"=>"",
          "remoteip"=>"127.0.0.1"
        })
      end
      
      it 're-renders the new form' do
        visit new_dummy_form_path
        expect(page).to have_selector("div.cf-turnstile[data-sitekey='1x00000000000000000000AA']")
        # Soft check that after_blocked proc is called
        expect_any_instance_of(BotChallengePage::Config).to receive(:after_blocked)
        find('input[type="submit"]').click
        expect(page).to have_text("Challenge failed", wait: 4)
      end
    end
  end
end