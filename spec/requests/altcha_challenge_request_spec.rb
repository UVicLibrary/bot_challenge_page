# frozen_string_literal: true
require 'rails_helper'

RSpec.describe "altcha challenge request", type: :request do
  describe 'verifying a challenge' do
    let(:challenge) do
      valid_options = Altcha::V2::CreateChallengeOptions.instance_method(:initialize).parameters.map(&:second)
      options = Altcha::V2::CreateChallengeOptions.new(
        **altcha_config.select { |key,_val| valid_options.include? key }
                    .merge(expires_at: expires_at))
      Altcha::V2.create_challenge(options)
    end

    let(:expires_at) { Time.now + altcha_config.fetch(:expires_at).seconds.to_i }
    
    # Keep the challenge cost very low so that tests run faster
    let(:altcha_config) do
      BotChallengePage::AltchaChallengeController.new
       .bot_challenge_config
       .altcha_challenge_options
       .merge({
               algorithm: "PBKDF2/SHA-256",
               cost: 10,
               counter: 1
             })
    end
    
    # Temporarily change desired mocked config
    # Kinda hacky because we need to keep re-registering the tracks
    around(:each) do |example|
      with_bot_challenge_config(BotChallengePage::AltchaChallengeController,
                                enabled: true,
                                challenge_provider: "altcha",
                                challenge_renderer: ->() {
                                  render 'bot_challenge_page/bot_challenge_page/altcha_challenge'
                                },
                                altcha_challenge_options: altcha_config,
                                challenge_logger: Rails.logger
      ) { example.run }
    end

    let(:solution) do
      Altcha::V2::Payload.new(challenge: challenge, solution: Altcha::V2.solve_challenge(challenge)).to_json
    end

    context 'and solution is valid' do
      it "sets a session key, caches the solution so it can't be reused" do
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
        repeat_solution = solution
        post '/altcha_challenge', params: { altcha: Base64.encode64(repeat_solution) }
        post '/altcha_challenge', params: { altcha: Base64.encode64(repeat_solution) }
        expect(response.status).to eq 400
        expect(response).not_to be_successful
        expect(JSON.parse(response.body)['message']).to eq 'Incorrect solution'
      end
    end
  end
end