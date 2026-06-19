# frozen_string_literal: true
class DummyFormController < ApplicationController
  include BotChallengePage::GuardForm

  before_action :prepare_challenge, only: :new
  before_action :verify_form, only: :create
  
  def new
  end
  
  def create
    render json: { params: params.permit(:altcha, :data, :cf_turnstile_response) }
  end

  def after_challenge_failure(result)
    flash[:alert] = result.message
    prepare_challenge
    render :new
  end
  
end