class Api::V1::UsersController < ApplicationController
  before_action :authenticate, only: [:update] #authorizes user to update THEIR own account

  def show
    user = User.find(params[:id])
    render json: user
  end

  def update
    user = User.find(params[:id])
    user.update(user_params)
    render json: { message: 'User updated successfully' }, status: :ok
  end 

  def login
    user = User.find_by(email: params[:email])  # Finds the user by email
    if user&.authenticate(params[:password])  # Checks if the user exists and verifies the password
      token = JWT.encode({ user_id: user.id }, Rails.application.credentials.secret_key_base)  # Generates a JWT token for the authenticated user
      render json: { token: token }  # Returns the JWT token in the response
    else
      render json: { error: 'Invalid email or password' }, status: :unauthorized  # Returns error if authentication fails
    end
  end

  private

  def user_params
    params.require(:user).permit(:name, :email, :password)  # Strong parameters to ensure only allowed attributes are passed
  end
end
