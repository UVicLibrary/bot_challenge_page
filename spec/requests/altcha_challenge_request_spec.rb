# frozen_string_literal: true
require 'rails_helper'

RSpec.describe "altcha challenge request", type: :request do
  include AltchaHelperMethods
  
  describe 'verifying a challenge', provider: :altcha do
    let(:challenge) { stub_altcha_challenge(expires_at: expires_at) }
    let(:altcha_config) { stub_altcha_config }
    let(:expires_at) { Time.now + altcha_config.fetch(:expires_at).seconds.to_i }
    let(:solution) do
      Altcha::V2::Payload.new(challenge: challenge, solution: Altcha::V2.solve_challenge(challenge)).to_json
    end

    context 'and solution is valid' do
      it "sets a session key, and caches the solution so it can't be reused" do
        post '/altcha_challenge', params: { altcha: Base64.encode64(solution) }
        expect(session[controller.bot_challenge_config.session_passed_key].keys).to include('f','t')
        cache_key = controller.cache_store.instance_variable_get(:@data).keys.first
        expect(controller.cache_store.fetch(cache_key)).to be_present
      end

      it 'sends a 200 response' do
        post '/altcha_challenge', params: { altcha: Base64.encode64(solution) }
        expect(response.status).to eq 200
        expect(response).to be_successful
      end

      context 'with redirect_for_challenge' do
        before { allow_any_instance_of(BotChallengePage::Config)
                   .to receive(:redirect_for_challenge).and_return true }

        it 'sets redirect_for_challenge to true in the response' do
          post '/altcha_challenge', params: { altcha: Base64.encode64(solution) }
          expect(response.status).to eq 200
          expect(response).to be_successful
          expect(JSON.parse(response.body)['redirect_for_challenge']).to be true
        end
      end
    end

    context 'and solution is expired' do
      let(:expires_at) { 0 }
      
      it 'logs a failed challenge and sends a 400 response' do
        post '/altcha_challenge', params: { altcha: Base64.encode64(solution) }
        expect(response.status).to eq 400
        expect(JSON.parse(response.body)['message']).to eq 'Challenge expired'
      end
    end
    
    context 'and solution is invalid' do
      before { allow_any_instance_of(Altcha::V2::VerifySolutionResult)
                 .to receive(:verified).and_return false }
      
      it 'logs a failed challenge and sends a 400 response' do
        expect(Rails.logger).to receive(:warn)
        post '/altcha_challenge', params: { altcha: Base64.encode64(solution) }
        expect(response.status).to eq 400
        expect(response).not_to be_successful
        expect(JSON.parse(response.body)['message']).to eq 'Incorrect solution'
      end
    end
    
    context 'and solution was already used (i.e. replay attack)' do
      it 'logs a failed challenge and sends a 400 response' do
        expect(Rails.logger).to receive(:warn)
        repeat_solution = solution
        post '/altcha_challenge', params: { altcha: Base64.encode64(repeat_solution) }
        post '/altcha_challenge', params: { altcha: Base64.encode64(repeat_solution) }
        expect(response.status).to eq 400
        expect(response).not_to be_successful
        expect(JSON.parse(response.body)['message']).to eq "Solution can't be reused"
      end
    end

    context 'and JSON parser error' do
      it 'logs the failed challenge and sends a 400 response' do
        expect(Rails.logger).to receive(:warn)
        post '/altcha_challenge', params: { altcha: Base64.encode64("") }
        expect(response.status).to eq 400
        expect(response).not_to be_successful
        expect(JSON.parse(response.body)['message']).to eq "Incorrect solution"
      end
    end
  end
end