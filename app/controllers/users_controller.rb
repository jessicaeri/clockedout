class UsersController < ApplicationController
  after_action :create_default_leave_type_and_balance
  # after_action :calculate_initial_accrued_hours

  # POST /api/v1/users
  # http POST :3000/api/v1/users \
  #   user[name]='John Doe' \
  #   user[email]='john@example.com' \
  #   user[password]='password' \
  #   user[password_confirmation]='password'
  def create
    @user = User.new(user_params)
    Rails.logger.info "Creating user with params: #{user_params.inspect}"
    if @user.save
      Rails.logger.info "User created successfully: #{@user.inspect}"
      render json: { message: 'User created successfully' }, status: :created
    else
      render json: { errors: @user.errors }, status: :unprocessable_entity
    end
  end

  private
  # Strong parameters to ensure only allowed attributes are passed
  def user_params
    params.require(:user).permit(:name, :email, :password, :password_confirmation, :start_date)
  end

  def create_default_leave_type_and_balance #auto creates leave type  (annual - 4.0 and sick - 4)and balance for user which they can edit if different
    
    Rails.logger.info "Starting leave type and balance creation for user #{@user.id}"
    
    begin
      # Creates default leave type
      default_leave_types = @user.leave_types.create!([ 
        {
          name: "Annual", 
          accrual_rate: 4.0, 
          accrual_period: "Biweekly"},
        {
          name: "Sick", 
          accrual_rate: 4.0, 
          accrual_period: "Biweekly"}
      ])
      
      Rails.logger.info "Created leave types: #{default_leave_types.inspect}"
      
      #Creates default leave balance for each default leave
      default_leave_types.each do |leave_type|
        accrued_hours = calculate_initial_accrued_hours(leave_type)
        Rails.logger.info "Calculated accrued hours: #{accrued_hours} for leave_type #{leave_type.id}"
        
        balance = @user.leave_balances.create!(
          leave_type_id: leave_type.id,
          accrued_hours: accrued_hours,
          used_hours: 0,
          user_id: @user.id
        )
        Rails.logger.info "Created leave balance: #{balance.inspect}"
      end
    rescue => e
      Rails.logger.error "Error creating leave types/balances: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
    end
  end
  
  #Calculates accrued leave based off the start_date provided by user and accrual rate
  def calculate_initial_accrued_hours(leave_type)
    Rails.logger.info "LEAVE CALCULATION: Starting calculation for #{leave_type.name}"
    Rails.logger.info "LEAVE CALCULATION: User start_date is #{@user.start_date.inspect}"
    
    return 0 unless @user.start_date.present?

    today = Date.today
    days_passed = (today - @user.start_date.to_date).to_i
    
    Rails.logger.info "LEAVE CALCULATION: Today=#{today}, start_date=#{@user.start_date}, days_passed=#{days_passed}"
    
    # Return 0 for future start dates
    if days_passed < 0
      Rails.logger.info "LEAVE CALCULATION: Future start date, returning 0"
      return 0 
    end
    
    Rails.logger.info "LEAVE CALCULATION: Accrual period=#{leave_type.accrual_period.downcase}, accrual_rate=#{leave_type.accrual_rate}"
    
    pay_periods = (days_passed / 14.0).floor
    Rails.logger.info "LEAVE CALCULATION: Pay periods completed: #{pay_periods} (#{days_passed} days / 14 days per period)"
    
    accrued_hours = case leave_type.accrual_period.downcase
    when "biweekly" #14 days - used for accrued leave (gov jobs mostly e.g. 4.0hrs per pay period)
      pay_period_calculation = (days_passed / 14.0).floor
      result = pay_period_calculation * leave_type.accrual_rate
      Rails.logger.info "LEAVE CALCULATION: Biweekly calculation: #{pay_period_calculation} periods * #{leave_type.accrual_rate} hours = #{result} hours"
      result
    when "monthly" #30 days
      monthly_calculation = (days_passed / 30.0).floor
      result = monthly_calculation * leave_type.accrual_rate
      Rails.logger.info "LEAVE CALCULATION: Monthly calculation: #{monthly_calculation} months * #{leave_type.accrual_rate} hours = #{result} hours"
      result
    when "yearly" #365 days - used for fix # of leave
      yearly_calculation = (days_passed / 365.0).floor
      result = yearly_calculation * leave_type.accrual_rate
      Rails.logger.info "LEAVE CALCULATION: Yearly calculation: #{yearly_calculation} years * #{leave_type.accrual_rate} hours = #{result} hours"
      result
    else
      Rails.logger.info "LEAVE CALCULATION: Unknown accrual period '#{leave_type.accrual_period.downcase}', returning 0"
      0
    end
    
    Rails.logger.info "LEAVE CALCULATION: Final accrued hours: #{accrued_hours} for #{leave_type.name}"
    accrued_hours
  end

end
