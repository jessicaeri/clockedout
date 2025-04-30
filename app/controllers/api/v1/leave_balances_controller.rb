class Api::V1::LeaveBalancesController < ApplicationController
  before_action :authorize_request
  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found

  # GET /api/v1/leave_balances/summary
  # Returns a summary of all leave balances for the current user
  def summary
    # Find all leave balances for the current user
    @leave_balances = current_user.leave_balances.includes(:leave_type)
    
    # Calculate the total accrued and used hours across all leave types
    total_accrued = @leave_balances.sum(:accrued_hours)
    total_used = @leave_balances.sum(:used_hours)
    
    # Group leave balances by type for easy display
    balances_by_type = {}
    
    # For each leave balance, add it to our organized hash
    @leave_balances.each do |balance|
      # Create a hash with the relevant information
      balances_by_type[balance.leave_type.name] = {
        id: balance.id,
        leave_type_id: balance.leave_type_id,
        leave_type_name: balance.leave_type.name,
        accrued_hours: balance.accrued_hours,
        used_hours: balance.used_hours,
        available_hours: balance.accrued_hours - balance.used_hours,
        accrual_rate: balance.leave_type.accrual_rate,
        accrual_period: balance.leave_type.accrual_period
      }
    end
    
    # Create a summary object with totals and individual balances
    summary = {
      total: {
        accrued_hours: total_accrued,
        used_hours: total_used,
        available_hours: total_accrued - total_used
      },
      by_type: balances_by_type
    }
    
    # Return the summary as JSON
    render json: summary
  end

  # GET /api/v1/leave_balances/:id
  # http :3000/api/v1/leave_balances/:id
  def show
    @leave_balance = LeaveBalance.find(params[:id])
    authorize @leave_balance #LeaveBalancePolicy#show?
    render json: @leave_balance
  end  

  def update
    @leave_balance = LeaveBalance.find(params[:id])
    authorize @leave_balance #LeaveBalancePolicy#update?

    # Store current values before update for comparison
    old_accrued_hours = @leave_balance.accrued_hours
    old_used_hours = @leave_balance.used_hours

    # Check if the user is manually changing values
    accrued_changing = params[:leave_balance][:accrued_hours].present?
    used_changing = params[:leave_balance][:used_hours].present?

    if @leave_balance.update(leave_balance_params)
      # Log the changes for debugging
      Rails.logger.info "Leave balance updated for user #{@leave_balance.user_id}: accrued_hours #{old_accrued_hours} -> #{@leave_balance.accrued_hours}, used_hours #{old_used_hours} -> #{@leave_balance.used_hours}"
      
      # Calculate available hours (what the user sees as their "balance")
      available_hours = @leave_balance.accrued_hours - @leave_balance.used_hours
      Rails.logger.info "Available leave hours after update: #{available_hours} hours"
      
      # If the user manually updated their hours, we should recalculate the total balance
      if accrued_changing || used_changing
        recalculate_balance(@leave_balance)
      end
      
      render json: @leave_balance
    else
      render json: { errors: @leave_balance.errors }, status: :unprocessable_entity
    end
  end

  private
  def leave_balance_params
    params.require(:leave_balance).permit(:accrued_hours, :used_hours)
  end

  # Recalculate the leave balance totals when hours change
  def recalculate_balance(leave_balance)
    Rails.logger.info "Recalculating balance for leave_balance #{leave_balance.id}"
    
    # Get the user and their leave type
    user = User.find(leave_balance.user_id)
    leave_type = LeaveType.find(leave_balance.leave_type_id)
    
    # Only update used_hours if it was specified in the parameters
    # Preserve the accrued_hours that were manually set
    if params[:leave_balance][:used_hours].present?
      Rails.logger.info "Used hours manually set to: #{leave_balance.used_hours}"
    end
    
    # Only recalculate accrued_hours if it wasn't manually specified
    if !params[:leave_balance][:accrued_hours].present?
      # Get the updated accrued hours based on current date and start date
      accrued_hours = calculate_accrued_hours(user, leave_type)
      
      # Update just the accrued hours
      leave_balance.update_column(:accrued_hours, accrued_hours)
      Rails.logger.info "Recalculated accrued hours: #{accrued_hours}"
    else
      Rails.logger.info "Accrued hours manually set to: #{leave_balance.accrued_hours}"
    end
  end

  # Calculate accrued hours based on start_date and leave type
  # This mirrors the logic in UsersController#calculate_accrued_hours
  def calculate_accrued_hours(user, leave_type)
    # Return 0 if no start date
    return 0 unless user.start_date.present?

    # Calculate days passed since start date
    today = Date.today
    days_passed = (today - user.start_date.to_date).to_i
    
    # Return 0 for future start dates
    return 0 if days_passed < 0
    
    # Calculate accrued hours based on accrual period
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

  # Optional: Method to handle record not found errors
  def record_not_found
    render json: { error: "Leave balance not found" }, status: :not_found # status 404
  end
end
