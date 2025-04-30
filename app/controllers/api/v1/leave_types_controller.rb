class Api::V1::LeaveTypesController < ApplicationController
  before_action :authorize_request
  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found

  # POST /api/v1/leave_types
  # http POST :3000/api/v1/leave_types \
  #   leave_type[name]='Vacation' \
  #   leave_type[accrual_rate]='4.0' \
  #   leave_type[accrual_period]='Biweekly'
  def create
    @leave_type = LeaveType.new(leave_type_params)
    authorize @leave_type #LeaveTypePolicy#create?
    if @leave_type.save
      # If this is a new leave type, we should create leave balances for all existing users
      create_leave_balances_for_all_users(@leave_type)
      
      render json: { message: 'Leave type created successfully' }, status: :created
    else
      render json: { errors: @leave_type.errors }, status: :unprocessable_entity
    end
  end

  # GET /api/v1/leave_types
  # http :3000/api/v1/leave_types
  def index
    @leave_types = policy_scope(LeaveType)
    
    render json: @leave_types
  end

  # GET /api/v1/leave_types/:id
  # http :3000/api/v1/leave_types/:id
  def show
    @leave_type = LeaveType.find(params[:id])
    authorize @leave_type #LeaveTypePolicy#show?
    render json: @leave_type
  end     

  # PATCH /api/v1/leave_types/:id
  # http PATCH :3000/api/v1/leave_types/:id \
  #   leave_type[name]='Vacation' \
  #   leave_type[accrual_rate]='4.0' \
  #   leave_type[accrual_period]='Biweekly'
  def update
    @leave_type = LeaveType.find(params[:id])
    authorize @leave_type #LeaveTypePolicy#update?
    
    # Store original values to check if anything important changed
    old_accrual_rate = @leave_type.accrual_rate
    old_accrual_period = @leave_type.accrual_period
    
    if @leave_type.update(leave_type_params)
      # Check if accrual parameters changed - if so, we need to recalculate all leave balances
      accrual_params_changed = old_accrual_rate != @leave_type.accrual_rate || 
                               old_accrual_period != @leave_type.accrual_period
      
      if accrual_params_changed
        Rails.logger.info "Leave type #{@leave_type.id} accrual parameters changed. Recalculating all affected leave balances."
        recalculate_all_leave_balances(@leave_type)
      end
      
      render json: { message: 'Leave type updated successfully' }, status: :ok
    else
      render json: { errors: @leave_type.errors }, status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/leave_types/:id
  # http DELETE :3000/api/v1/leave_types/:id
  def destroy
    @leave_type = LeaveType.find(params[:id])
    authorize @leave_type #LeaveTypePolicy#destroy?
    @leave_type.destroy
    render json: { message: 'Leave type deleted successfully' }, status: :ok
    head :no_content # status 204 No Content - Standard practice for successful delete
  end

  private

  def leave_type_params
    params.require(:leave_type).permit(:name, :accrual_rate, :accrual_period)
  end
  
  # Optional: Method to handle record not found errors
  def record_not_found
    render json: { error: "Leave type not found" }, status: :not_found # status 404
  end
  
  # Recalculate all leave balances for a given leave type
  def recalculate_all_leave_balances(leave_type)
    # Find all leave balances associated with this leave type
    leave_balances = LeaveBalance.where(leave_type_id: leave_type.id)
    
    Rails.logger.info "Found #{leave_balances.count} leave balances to recalculate for leave type '#{leave_type.name}'"
    
    # For each leave balance, recalculate the accrued hours
    leave_balances.each do |balance|
      # Get the user associated with this leave balance
      user = User.find(balance.user_id)
      
      # Calculate new accrued hours
      accrued_hours = calculate_accrued_hours(user, leave_type)
      
      # Update the leave balance with the new accrued hours
      old_accrued_hours = balance.accrued_hours
      balance.update(accrued_hours: accrued_hours)
      
      Rails.logger.info "Updated leave balance #{balance.id}: accrued_hours changed from #{old_accrued_hours} to #{accrued_hours}"
    end
  end
  
  # Calculate accrued hours based on start_date and leave type
  # Using the same logic as in other controllers for consistency
  def calculate_accrued_hours(user, leave_type)
    # Return 0 if no start date
    return 0 unless user.start_date.present?

    # Calculate days passed since start date
    today = Date.today
    days_passed = (today - user.start_date.to_date).to_i
    
    # Return 0 for future start dates
    return 0 if days_passed < 0
    
    # Calculate accrued hours based on accrual period - use downcase for case-insensitivity
    case leave_type.accrual_period.downcase
    when "biweekly" # 14 days
      (days_passed / 14.0).floor * leave_type.accrual_rate
    when "monthly" # 30 days
      (days_passed / 30.0).floor * leave_type.accrual_rate
    when "yearly" # 365 days
      (days_passed / 365.0).floor * leave_type.accrual_rate
    else
      0
    end
  end
  
  # Create leave balances for all users when a new leave type is added
  def create_leave_balances_for_all_users(leave_type)
    # Get all users
    users = User.all
    
    Rails.logger.info "Creating leave balances for new leave type '#{leave_type.name}' for #{users.count} users"
    
    # For each user, create a new leave balance for this leave type
    users.each do |user|
      # Calculate accrued hours based on the user's start date and the leave type
      accrued_hours = calculate_accrued_hours(user, leave_type)
      
      # Create a new leave balance for this user and leave type with the calculated accrued hours
      leave_balance = LeaveBalance.new(
        user_id: user.id,
        leave_type_id: leave_type.id,
        accrued_hours: accrued_hours,
        used_hours: 0
      )
      
      if leave_balance.save
        Rails.logger.info "Created leave balance for user #{user.id} with #{accrued_hours} accrued hours"
      else
        Rails.logger.error "Failed to create leave balance for user #{user.id}: #{leave_balance.errors.full_messages.join(', ')}"
      end
    end
  end
end
