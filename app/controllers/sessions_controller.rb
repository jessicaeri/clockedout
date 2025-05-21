class SessionsController < ApplicationController
  #SLACK MARCH 3rd EXERCISES
  require 'jwt'

  def create
    # Get email from params, supporting both nested and direct parameters
    email = params[:email] || (params[:Session] && params[:Session][:email]) || (params[:session] && params[:session][:email]) || (params[:user] && params[:user][:email])
    
    # Get password from params, supporting both nested and direct parameters  
    password = params[:password] || (params[:Session] && params[:Session][:password]) || (params[:session] && params[:session][:password]) || (params[:user] && params[:user][:password])
    
    # Debug: Log which params are being used
    Rails.logger.info "Login attempt: email param = #{email}, password present = #{password.present?}"
    
    # Make email case-insensitive by downcasing it
    email = email.to_s.downcase if email.present?
    
    @user = User.find_by(email: email) # Finds the user by email
    Rails.logger.info "User lookup: found = #{@user.present?}"

    if @user && @user.authenticate(password) # Checks if the user exists and verifies the password
      token = JWT.encode({ user_id: @user.id }, Rails.application.credentials.secret_key_base) # Generates a JWT token for the authenticated user

      render json: { jwt: token, user: @user }, status: :created # Returns the JWT token in the response
    else
      # TEMP: More granular error for debugging
      if !@user
        render json: { error: 'User not found for email' }, status: :unauthorized
      else
        render json: { error: 'Incorrect password' }, status: :unauthorized
      end
    end
  end
  
  def destroy
    session.delete(:user_id)
    redirect_to login_path, notice: 'Logged out successfully!'
  end

  private
  # Strong parameters to ensure only allowed attributes are passed
  def user_params
    params.require(:user).permit(:email, :password)
  end
end