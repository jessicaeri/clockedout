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
    start_date_changing = params[:user][:start_date].present? && @user.start_date.to_s != params[:user][:start_date]
    
    # Keep track of the old and new start dates for logging
    old_start_date = @user.start_date
    
    if @user.update(user_params)
      # If the start date was changed, recalculate all leave balances
      if start_date_changing
        Rails.logger.info "User #{@user.id} start date changed from #{old_start_date} to #{@user.start_date}. Recalculating leave balances."
        recalculate_leave_balances(@user)
      end
      
      render json: { message: 'User updated successfully' }, status: :ok
    else
      render json: { errors: @user.errors }, status: :unprocessable_entity
    end
  end 

  private

  # Strong parameters to ensure only allowed attributes are passed
  def user_params
    params.require(:user).permit(:name, :email, :password, :password_confirmation, :start_date)
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
    # Return 0 if no start date
    return 0 unless user.start_date.present?

    # Calculate days passed since start date
    today = Date.today
    days_passed = (today - user.start_date.to_date).to_i
    
    Rails.logger.info "LEAVE RECALCULATION: Today=#{today}, start_date=#{user.start_date}, days_passed=#{days_passed}"

    # Return 0 for future start dates
    if days_passed < 0
      Rails.logger.info "LEAVE RECALCULATION: Future start date, returning 0"
      return 0 
    end
    
    Rails.logger.info "LEAVE RECALCULATION: Accrual period=#{leave_type.accrual_period.downcase}, accrual_rate=#{leave_type.accrual_rate}"
    
    pay_periods = (days_passed / 14.0).floor
    Rails.logger.info "LEAVE RECALCULATION: Pay periods completed: #{pay_periods} (#{days_passed} days / 14 days per period)"
    
    accrued_hours = case leave_type.accrual_period.downcase
    when "biweekly" #14 days - used for accrued leave (gov jobs mostly e.g. 4.0hrs per pay period)
      pay_period_calculation = (days_passed / 14.0).floor
      result = pay_period_calculation * leave_type.accrual_rate
      Rails.logger.info "LEAVE RECALCULATION: Biweekly calculation: #{pay_period_calculation} periods * #{leave_type.accrual_rate} hours = #{result} hours"
      result
    when "monthly" #30 days
      monthly_calculation = (days_passed / 30.0).floor
      result = monthly_calculation * leave_type.accrual_rate
      Rails.logger.info "LEAVE RECALCULATION: Monthly calculation: #{monthly_calculation} months * #{leave_type.accrual_rate} hours = #{result} hours"
      result
    when "yearly" #365 days - used for fix # of leave
      yearly_calculation = (days_passed / 365.0).floor
      result = yearly_calculation * leave_type.accrual_rate
      Rails.logger.info "LEAVE RECALCULATION: Yearly calculation: #{yearly_calculation} years * #{leave_type.accrual_rate} hours = #{result} hours"
      result
    else
      Rails.logger.info "LEAVE RECALCULATION: Unknown accrual period '#{leave_type.accrual_period.downcase}', returning 0"
      0
    end
    
    Rails.logger.info "LEAVE RECALCULATION: Final accrued hours: #{accrued_hours} for #{leave_type.name}"
    accrued_hours
  end
end
