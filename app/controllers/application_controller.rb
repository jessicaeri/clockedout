class ApplicationController < ActionController::API
  #GITHUB AUTHENTICATION GUIDE
  include Pundit  # Enables Pundit methods in all controllers
  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized  # Handles unauthorized access
  
  #GITHUB AUTHENTICATION GUIDE
  def authorize_request
    header = request.headers['Authorization']
    token = header.split(' ').last if header
    begin
      decoded = JWT.decode(token, Rails.application.credentials.secret_key_base)[0]
      @current_user = User.find(decoded['user_id'])
    rescue ActiveRecord::RecordNotFound, JWT::DecodeError
      render json: { errors: 'Unauthorized' }, status: :unauthorized
    end
  end

  def current_user
    @current_user
  end

  def logged_in?
    current_user.present?
  end

  private
  
  def user_not_authorized
    render json: { error: 'You are not authorized to perform this action.' }, status: :forbidden  # Returns forbidden error for unauthorized actions
  end
end
