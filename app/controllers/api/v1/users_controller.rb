class Api::V1::UsersController < ApplicationController
  before_action :authorize_request #authorizes user to update THEIR own account
  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found

  # GET /api/v1/users/:id
  # http :3000/api/v1/users/:id
  def show
    @user = User.find(params[:id])
    authorize @user #UserPolicy#show?
    render json: @user
  end

  # PATCH /api/v1/users/:id
  # http PATCH :3000/api/v1/users/:id \
  #   user[name]='John Doe' \
  #   user[email]='john@example.com' \
  #   user[password]='password'
  def update
    @user = User.find(params[:id])
    authorize @user #UserPolicy#update?
    
    # Store whether the start date is changing
    start_date_changing = params[:user]&.[](:start_date).present? && @user.start_date.to_s != params[:user]&.[](:start_date)
    
    # Keep track of the old and new start dates for logging
    old_start_date = @user.start_date
    
    # Log the parameters we're trying to update with
    Rails.logger.info "Attempting to update user #{@user.id} with params: #{user_params.inspect}"
    
    if @user.update(user_params)
      # If the start date was changed, recalculate all leave balances
      if start_date_changing
        Rails.logger.info "User #{@user.id} start date changed from #{old_start_date} to #{@user.start_date}. Recalculating leave balances."
        recalculate_leave_balances(@user)
      end
      
      render json: { message: 'User updated successfully' }, status: :ok
    else
      # Log the specific validation errors
      Rails.logger.error "User update failed: #{@user.errors.full_messages.join(', ')}"
      render json: { errors: @user.errors.full_messages }, status: :unprocessable_entity
    end
  end 

  private

  # Strong parameters to ensure only allowed attributes are passed
  def user_params
    # If user params are nested under 'user', use them
    # Otherwise, collect them from the top level
    if params[:user].present?
      params_to_use = params.require(:user)
    else
      # Create a new params object with only the user-related keys
      params_to_use = ActionController::Parameters.new(
        name: params[:name],
        email: params[:email],
        password: params[:password],
        password_confirmation: params[:password_confirmation],
        start_date: params[:start_date]
      )
    end
    
    # For profile updates (PATCH/PUT), only include password parameters if they are provided
    # This prevents the password validation from running when not updating the password
    if request.patch? || request.put?
      # Only include password-related fields if explicitly provided
      permitted_params = [:name, :email, :start_date]
      if params_to_use[:password].present?
        permitted_params += [:password, :password_confirmation]
      end
      return params_to_use.permit(*permitted_params)
    end
    
    # For other actions (like create), permit all allowed attributes
    params_to_use.permit(:name, :email, :password, :password_confirmation, :start_date)
  end

  # Optional: Method to handle record not found errors
  def record_not_found
    render json: { error: "User not found" }, status: :not_found # status 404
  end

  # Calculate new accrued hours when a user's start date changes
  def recalculate_leave_balances(user)
    # Skip if user has no leave types or balances
    return unless user.leave_types.any? && user.leave_balances.any?
    
    # Process each leave balance
    user.leave_balances.each do |balance|
      # Find the associated leave type
      leave_type = user.leave_types.find(balance.leave_type_id)
      
      # Calculate the new accrued hours
      accrued_hours = calculate_accrued_hours(user, leave_type)
      
      # Update the balance with the new amount
      balance.update(accrued_hours: accrued_hours)
      
      Rails.logger.info "Updated leave balance: user=#{user.id}, type=#{leave_type.name}, accrued_hours=#{accrued_hours}"
    end
  end
  
  # Calculate accrued hours based on start_date and leave type
  def calculate_accrued_hours(user, leave_type)
    Rails.logger.info "LEAVE RECALCULATION: Starting recalculation for #{leave_type.name}"
    Rails.logger.info "LEAVE RECALCULATION: User's updated start date is #{user.start_date.inspect}"
    
    # For one-time accrual types (like comp time), we don't auto-calculate accruals
    # Instead, we preserve the existing accrued hours and only change through manual adjustments
    if leave_type.one_time_accrual
      # Find existing leave balance to maintain current accrued hours
      existing_balance = LeaveBalance.find_by(user_id: user.id, leave_type_id: leave_type.id)
      return existing_balance&.accrued_hours || leave_type.accrual_rate || 0
    end
    
    # For regular accrual types, calculate as normal
    # Return 0 if no start date
    return 0 unless user.start_date.present?

    # Calculate days passed since start date
    today = Date.today
    days_passed = (today - user.start_date.to_date).to_i
    
    # Return 0 for future start dates
    return 0 if days_passed < 0
    
    # Get accrual period and downcase it for case-insensitive comparison
    accrual_period = leave_type.accrual_period&.downcase
    
    # Calculate accrued hours based on accrual period
    Rails.logger.info "LEAVE RECALCULATION: Accrual period=#{accrual_period}, accrual_rate=#{leave_type.accrual_rate}"
    
    case accrual_period
    when "biweekly" # 14 days
      biweekly_calculation = (days_passed / 14.0).floor
      result = biweekly_calculation * leave_type.accrual_rate
      Rails.logger.info "LEAVE RECALCULATION: Biweekly calculation: #{biweekly_calculation} periods * #{leave_type.accrual_rate} hours = #{result} hours"
      result
    when "monthly" # 30 days
      monthly_calculation = (days_passed / 30.0).floor
      result = monthly_calculation * leave_type.accrual_rate
      Rails.logger.info "LEAVE RECALCULATION: Monthly calculation: #{monthly_calculation} months * #{leave_type.accrual_rate} hours = #{result} hours"
      result
    when "yearly" # 365 days - used for fix # of leave
      yearly_calculation = (days_passed / 365.0).floor
      result = yearly_calculation * leave_type.accrual_rate
      Rails.logger.info "LEAVE RECALCULATION: Yearly calculation: #{yearly_calculation} years * #{leave_type.accrual_rate} hours = #{result} hours"
      result
    else
      Rails.logger.info "LEAVE RECALCULATION: Unknown accrual period '#{leave_type.accrual_period.downcase}', returning 0"
      0
    end
    
    # Use the last result from the case statement instead of a non-existent variable
    # This fixes the "undefined local variable accrued_hours" error
    final_hours = case accrual_period
    when "biweekly" then (days_passed / 14.0).floor * leave_type.accrual_rate
    when "monthly" then (days_passed / 30.0).floor * leave_type.accrual_rate
    when "yearly" then (days_passed / 365.0).floor * leave_type.accrual_rate
    else 0
    end
    
    Rails.logger.info "LEAVE RECALCULATION: Final accrued hours: #{final_hours} for #{leave_type.name}"
    final_hours
  end
end
