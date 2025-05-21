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
    # Check for user_id in the model before saving
    @leave_type.user_id = current_user.id
    
    # Log parameters for debugging
    Rails.logger.info "Creating leave type with params: #{leave_type_params.inspect}"
    
    # Handle the one_time_accrual parameter specifically
    # Convert string "true" to boolean true
    if leave_type_params[:one_time_accrual].is_a?(String)
      @leave_type.one_time_accrual = (leave_type_params[:one_time_accrual] == "true")
    end
    
    Rails.logger.info "Leave type object before save: #{@leave_type.inspect}"
    
    if @leave_type.save
      # If this is a new leave type, we should create leave balances for all existing users
      create_leave_balances_for_all_users(@leave_type)
      
      render json: { message: 'Leave type created successfully' }, status: :created
    else
      Rails.logger.error "Failed to create leave type: #{@leave_type.errors.full_messages.join(', ')}"
      render json: { errors: @leave_type.errors.full_messages }, status: :unprocessable_entity
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
    old_name = @leave_type.name
    old_accrual_rate = @leave_type.accrual_rate
    old_accrual_period = @leave_type.accrual_period
    
    # Add debugging for incoming parameters
    Rails.logger.info "Updating leave type #{@leave_type.id} with params: #{leave_type_params.inspect}"
    Rails.logger.info "Old accrual_rate: #{old_accrual_rate} (#{old_accrual_rate.class})"
    
    if @leave_type.update(leave_type_params)
      # Add debugging for updated values
      Rails.logger.info "New accrual_rate: #{@leave_type.accrual_rate} (#{@leave_type.accrual_rate.class})"
      
      # Check if accrual parameters changed - if so, we need to recalculate all leave balances
      accrual_params_changed = old_accrual_rate != @leave_type.accrual_rate || 
                               old_accrual_period != @leave_type.accrual_period
      
      Rails.logger.info "Accrual params changed? #{accrual_params_changed}"
      Rails.logger.info "Comparison: #{old_accrual_rate} != #{@leave_type.accrual_rate} = #{old_accrual_rate != @leave_type.accrual_rate}"
      
      if accrual_params_changed
        Rails.logger.info "Leave type #{@leave_type.id} accrual parameters changed. Recalculating all affected leave balances."
        recalculate_all_leave_balances(@leave_type)
      else
        Rails.logger.info "No accrual parameter changes detected, skipping recalculation."
      end
      
      render json: { message: 'Leave type updated successfully' }, status: :ok
    else
      Rails.logger.error "Failed to update leave type: #{@leave_type.errors.full_messages.join(', ')}"
      render json: { errors: @leave_type.errors }, status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/leave_types/:id
  # http DELETE :3000/api/v1/leave_types/:id
  def destroy
    @leave_type = LeaveType.find(params[:id])
    authorize @leave_type #LeaveTypePolicy#destroy?
    
    # Check if this leave type has any dependent records
    balance_count = LeaveBalance.where(leave_type_id: @leave_type.id).count
    request_count = LeaveRequest.where(leave_type_id: @leave_type.id).count
    
    Rails.logger.info "Attempting to delete leave type #{@leave_type.id} (#{@leave_type.name}). Associated records: #{balance_count} balances, #{request_count} requests"
    
    # Try to destroy and catch any errors
    begin
      if @leave_type.destroy
        Rails.logger.info "Successfully deleted leave type #{@leave_type.id}"
        return render json: { message: 'Leave type deleted successfully' }, status: :ok
      else
        Rails.logger.error "Failed to delete leave type: #{@leave_type.errors.full_messages.join(', ')}"
        return render json: { errors: @leave_type.errors.full_messages }, status: :unprocessable_entity
      end
    rescue => e
      Rails.logger.error "Exception when deleting leave type: #{e.message}"
      return render json: { error: "Cannot delete this leave type because it has associated balances or requests. Please delete those first." }, status: :unprocessable_entity
    end
  end

  private

  def leave_type_params
    # If params[:leave_type] exists, use it; otherwise, build it from top-level params
    if params[:leave_type].present?
      params.require(:leave_type).permit(:name, :accrual_rate, :accrual_period, :one_time_accrual)
    elsif params[:Leave_type].present?
      # Handle capitalized version
      params.require(:Leave_type).permit(:name, :accrual_rate, :accrual_period, :one_time_accrual)
    else
      # Create a new hash with only the permitted parameters
      ActionController::Parameters.new(
        leave_type: {
          name: params[:name],
          accrual_rate: params[:accrual_rate],
          accrual_period: params[:accrual_period],
          one_time_accrual: params[:one_time_accrual]
        }
      ).require(:leave_type).permit(:name, :accrual_rate, :accrual_period, :one_time_accrual)
    end
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
      
      # Update the leave balance with the new accrued hours ONLY
      # Keep the used_hours unchanged to maintain accurate tracking
      old_accrued_hours = balance.accrued_hours
      balance.update_column(:accrued_hours, accrued_hours) # Only update the accrued_hours column
      
      Rails.logger.info "Updated leave balance #{balance.id}: accrued_hours changed from #{old_accrued_hours} to #{accrued_hours}, used_hours preserved at #{balance.used_hours}"
    end
  end
  
  # Calculate accrued hours based on start_date and leave type
  # Using the same logic as in other controllers for consistency
  def calculate_accrued_hours(user, leave_type)
    # For one-time accrual types (like comp time), use the accrual_rate directly
    # This allows setting an initial balance for comp time
    if leave_type.one_time_accrual
      Rails.logger.info "One-time accrual type detected. Setting initial balance to #{leave_type.accrual_rate}"
      return leave_type.accrual_rate
    end
    
    # For regular accrual types, calculate as normal
    # Return 0 if no start date
    return 0 unless user.start_date.present?

    # Calculate days passed since start date
    today = Date.today
    days_passed = (today - user.start_date.to_date).to_i
    
    # Return 0 for future start dates
    return 0 if days_passed < 0
    
    # Calculate accrued hours based on accrual period - use downcase for case-insensitivity
    case leave_type.accrual_period&.downcase
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
