class ApplicationController < ActionController::API
  include Pundit  # Enables Pundit methods in all controllers
  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized  # Handles unauthorized access
  
  private
  
  def user_not_authorized
    render json: { error: 'You are not authorized to perform this action.' }, status: :forbidden  # Returns forbidden error for unauthorized actions
  end
end
