class Api::V1::CommentsController < ApplicationController
  respond_to :json, :xml

  before_action :find_problem
  skip_before_action :authenticate_user!, only: :create
  before_action :require_api_key_or_authenticate_user!, only: :create

  FIELDS = %w{_id created_at updated_at body err_id user_id}

  def show
    comment = benchmark("[api/v1/comments_controller/show] query time") do
      begin
        comments_scope.only(FIELDS).find(params[:id])
      rescue Mongoid::Errors::DocumentNotFound
        head :not_found
        return false
      end
    end

    respond_to do |format|
      format.any(:html, :json) { render json: comment.attributes }
      format.xml { render xml: comment.attributes }
    end
  end

  def create
    response = { success: false }

    if current_user
      if params[:problem_id]
        @comment = Comment.new
        @comment[:user_id] = current_user.id
        params.each { |k, v| @comment[k] = v }

        if @comment.valid?
          problem = Problem.where(id: params[:problem_id]).last
          if problem
            problem.comments << @comment
            response[:success] = problem.save
            unless response[:success]
              response[:message] = "invalid problem"
            end
          else
            response[:message] = "invalid problem id"
          end
        else
          response[:message] = "invalid comment"
        end
      else
        response[:message] = "no problem id"
      end
    else
      response[:message] = "not logged in"
    end

    respond_to do |format|
      format.any(:html, :json) { render json: response }
      format.xml { render xml: response }
    end
  end

protected

  def find_problem
    @problem = Problem.where(comment: @comment).last
  end

private

  def generate_authentication_token
    loop do
      token = Devise.friendly_token
      break token unless User.where(authentication_token: token).first
    end
  end

  def ensure_errbot_user
    errbot = User.where(name: "Errbot").last
    unless errbot
      errbot = User.new
      errbot.name = "Errbot"
      errbot.email = "programmers@bonanza.com"
      errbot.password = "?????????????" # FIXME: before merging
      errbot.authentication_token = generate_authentication_token
      errbot.save!
    end
    errbot
  end
end
