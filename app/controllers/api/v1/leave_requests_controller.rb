class Api::V1::LeaveRequestsController < ApplicationController
  before_action :authorize_request
  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found

  # POST /api/v1/leave_requests
  # http POST :3000/api/v1/leave_requests \
  #   leave_request[start_date]='2025-07-01' \
  #   leave_request[end_date]='2025-07-01' \
  #   leave_request[requested_hours]='8.0'
  def create
    @leave_request = LeaveRequest.new(leave_request_params)
    @leave_request.user_id = @current_user.id  # Make sure the user ID is set
    
    authorize @leave_request #LeaveRequestPolicy#create?
    
    # Auto-calculate requested_hours if start_date and end_date are present
    #Calculates based off start date's start time to end date's end time
      #Example:
          #Start: May 9th - 0800 
          #End: May 9th - 1700 (5PM)
          #Calulation: 1700 - 0800 = 0900 but accounts for 1hour lunch 
    if @leave_request.start_date.present? && @leave_request.end_date.present?
      # Calculate hours based on dates and times
      hours = calculate_hours(@leave_request.start_date, @leave_request.end_date, @leave_request.start_time, @leave_request.end_time)
      @leave_request.requested_hours = hours
    end
    
    Rails.logger.info "Attempting to create leave request: #{@leave_request.attributes.inspect}"
    
    if @leave_request.save
      # Load the leave request with associations to include in the response
      loaded_request = LeaveRequest.includes(:leave_type).find(@leave_request.id)
      
      # Create a custom response that has all the necessary data in the correct format
      response_data = {
        id: loaded_request.id,
        start_date: loaded_request.start_date,
        end_date: loaded_request.end_date,
        start_time: loaded_request.start_time,
        end_time: loaded_request.end_time,
        leave_type_id: loaded_request.leave_type_id,
        leave_type: loaded_request.leave_type,
        status: loaded_request.status,
        requested_hours: loaded_request.requested_hours,
        user_id: loaded_request.user_id
      }
      
      render json: { 
        message: 'Leave request created successfully',
        leave_request: response_data
      }, status: :created
    else
      Rails.logger.error "Failed to create leave request: #{@leave_request.errors.full_messages.join(', ')}"
      render json: { errors: @leave_request.errors }, status: :unprocessable_entity
    end
  end

  # GET /api/v1/leave_requests
  # http :3000/api/v1/leave_requests
  def index
    @leave_requests = policy_scope(LeaveRequest)
    render json: @leave_requests
  end

  
  # GET /api/v1/leave_requests/calculate_hours
  # API endpoint for calculating leave hours without creating a leave request

  #Calculates based off start date's start time to end date's end time
      #Example:
          #Start: May 9th - 0800 
          #End: May 9th - 1700 (5PM)
          #Calulation: 1700 - 0800 = 0900 but accounts for 1hour lunch 
  def calculate_hours
    start_date = params[:start_date].presence
    end_date = params[:end_date].presence
    start_time = params[:start_time].presence
    end_time = params[:end_time].presence
    
    if start_date.blank? || end_date.blank?
      return render json: { error: 'Start date and end date are required' }, status: :bad_request
    end
    
    hours = calculate_hours(start_date, end_date, start_time, end_time)
    
    # Create detailed breakdown for response
    details = {
      start_date: start_date,
      end_date: end_date,
      start_time: start_time || '08:00',
      end_time: end_time || '16:00',
      total_hours: hours
    }
    
    Rails.logger.info "API HOURS CALCULATION: #{details.inspect}"
    
    render json: {
      hours: hours,
      details: details
    }
  end
  


  # GET /api/v1/leave_requests/:id
  # http :3000/api/v1/leave_requests/:id
  def show
    @leave_request = LeaveRequest.find(params[:id])
    authorize @leave_request #LeaveRequestPolicy#show?
    render json: @leave_request
  end     

  # PATCH /api/v1/leave_requests/:id
  # http PATCH :3000/api/v1/leave_requests/:id \
  #   leave_request[start_date]='2025-07-01' \
  #   leave_request[end_date]='2025-07-01' \
  #   leave_request[requested_hours]='8.0'
  def update
    @leave_request = LeaveRequest.find(params[:id])
    authorize @leave_request
    
    old_status = @leave_request.status
    
    # Only recalculate hours if dates or times are changing, not for status updates alone
    if params[:leave_request][:start_date].present? || params[:leave_request][:end_date].present? ||
       params[:leave_request][:start_time].present? || params[:leave_request][:end_time].present?
      
      new_start = params[:leave_request][:start_date] || @leave_request.start_date
      new_end = params[:leave_request][:end_date] || @leave_request.end_date
      new_start_time = params[:leave_request][:start_time] || @leave_request.start_time
      new_end_time = params[:leave_request][:end_time] || @leave_request.end_time
      
      # Use our dynamic calculation method for consistent hour calculation
      Rails.logger.info "UPDATE: Calculating hours"
      hours = calculate_hours(new_start, new_end, new_start_time, new_end_time)
      params[:leave_request][:requested_hours] = hours
      
      Rails.logger.info "UPDATE: Hours calculated: #{hours}"
    end
    
    # If the request is being edited (any field except status is changed), 
    # set status to "pending" unless the user is explicitly changing the status
    if request_is_being_edited?(params[:leave_request]) && !params[:leave_request][:status].present?
      params[:leave_request][:status] = LeaveRequest::STATUS_PENDING
    end
    
    if @leave_request.update(leave_request_params)
      # If status has changed, update the balance
      if old_status != @leave_request.status
        update_leave_balance_for_status_change(@leave_request, old_status, @leave_request.status)
      end
      
      render json: @leave_request
    else
      render json: @leave_request.errors, status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/leave_requests/:id
  # http DELETE :3000/api/v1/leave_requests/:id
  def destroy
    @leave_request = LeaveRequest.find(params[:id])
    authorize @leave_request #LeaveRequestPolicy#destroy?
    
    # If this request affects balance, we need to restore hours
    if affecting_balance?(@leave_request)
      restore_leave_balance(@leave_request)
    end
    
    @leave_request.destroy
    render json: { message: 'Leave request deleted successfully' }, status: :ok
    head :no_content # status 204 No Content - Standard practice for successful delete
  end

  # POST /api/v1/leave_requests/:id/submit
  # http POST :3000/api/v1/leave_requests/:id/submit
  def submit
    @leave_request = LeaveRequest.find(params[:id])
    authorize @leave_request #LeaveRequestPolicy#update?
    
    if @leave_request.status == LeaveRequest::STATUS_PLANNED
      if @leave_request.update(status: LeaveRequest::STATUS_PENDING)
        render json: { message: 'Leave request submitted for approval' }, status: :ok
      else
        render json: { errors: @leave_request.errors }, status: :unprocessable_entity
      end
    else
      render json: { error: 'Only planned requests can be submitted' }, status: :unprocessable_entity
    end
  end
  
  # POST /api/v1/leave_requests/:id/approve
  # http POST :3000/api/v1/leave_requests/:id/approve
  def approve
    @leave_request = LeaveRequest.find(params[:id])
    authorize @leave_request #LeaveRequestPolicy#update?
    
    old_status = @leave_request.status
    
    if @leave_request.update(status: LeaveRequest::STATUS_APPROVED)
      update_leave_balance_for_status_change(@leave_request, old_status, LeaveRequest::STATUS_APPROVED)
      render json: { message: 'Leave request approved' }, status: :ok
    else
      render json: { errors: @leave_request.errors }, status: :unprocessable_entity
    end
  end
  
  # POST /api/v1/leave_requests/:id/cancel
  # http POST :3000/api/v1/leave_requests/:id/cancel
  def cancel
    @leave_request = LeaveRequest.find(params[:id])
    authorize @leave_request #LeaveRequestPolicy#update?
    
    old_status = @leave_request.status
    
    if @leave_request.update(status: LeaveRequest::STATUS_CANCELED)
      update_leave_balance_for_status_change(@leave_request, old_status, LeaveRequest::STATUS_CANCELED)
      render json: { message: 'Leave request canceled' }, status: :ok
    else
      render json: { errors: @leave_request.errors }, status: :unprocessable_entity
    end
  end
  
  # GET /api/v1/leave_requests/projected_balance
  # http :3000/api/v1/leave_requests/projected_balance?leave_type_id=1&date=2025-12-31
  def projected_balance
    #HTTPIE
    unless params[:leave_type_id].present? && params[:date].present?
      return render json: { error: 'leave_type_id and date parameters are required' }, status: :bad_request
    end
    
    #Gt the user's current balance
    leave_type_id = params[:leave_type_id]
    current_balance = current_user.leave_balances.find_by(leave_type_id: leave_type_id)
    
    #should have current balances made unless deleted by user
    unless current_balance
      return render json: { error: 'Leave balance not found for this leave type' }, status: :not_found
    end
    
    #Find the leave type
    leave_type = LeaveType.find(leave_type_id)
    
    #Calculate accrual by future date
    begin
      future_date = Date.parse(params[:date])
    rescue ArgumentError
      return render json: { error: 'Invalid date format. Use YYYY-MM-DD.' }, status: :bad_request
    end
    
    if future_date <= Date.today
      return render json: { error: 'Projected date must be in the future' }, status: :bad_request
    end
    
    # Get current balance values and ensure they're not nil
    current_accrued = current_balance.accrued_hours || 0
    current_used = current_balance.used_hours || 0
    
    # IMPORTANT FIX: 
    # Get all leave requests affecting balance
    past_leave_requests = current_user.leave_requests
                          .affecting_balance
                          .where('start_date <= ?', Date.today)
    past_used = past_leave_requests.sum(:requested_hours) || 0
    
    # Get future leave requests
    future_leave_requests = current_user.leave_requests
                             .affecting_balance
                             .where('start_date > ?', Date.today)
                             .where('start_date <= ?', future_date)
    future_used = future_leave_requests.sum(:requested_hours) || 0
    
    # Calculate future accrual based on leave type settings
    future_accrual = calculate_future_accrual(current_user, leave_type, future_date) || 0
    
    current_available = current_accrued - past_used
    projected_accrued = current_accrued + future_accrual
    projected_available = current_available + future_accrual - future_used
    
    
    # Comprehensive logging to help with debugging
    Rails.logger.info "===== PROJECTED BALANCE CALCULATION ====="
    Rails.logger.info "CURRENT FROM DB: accrued=#{current_accrued}, used=#{current_used}"
    Rails.logger.info "CALCULATED: past_used=#{past_used}, future_used=#{future_used}"
    Rails.logger.info "CURRENT AVAILABLE (#{current_accrued} - #{past_used}): #{current_available}"
    Rails.logger.info "FUTURE ACCRUAL: #{future_accrual}"
    Rails.logger.info "FORMULA: #{current_available} + #{future_accrual} - #{future_used} = #{projected_available}"
    
    # Log individual future leave requests for detailed debugging
    if future_leave_requests.any?
      Rails.logger.info "FUTURE LEAVE REQUESTS:"
      future_leave_requests.each do |req|
        Rails.logger.info "  - #{req.id}: #{req.start_date} to #{req.end_date}, #{req.requested_hours} hours, status: #{req.status}"
      end
    else
      Rails.logger.info "NO FUTURE LEAVE REQUESTS FOUND"
    end
    
    
    # Build the response
    projected = {
      as_of_date: future_date,
      leave_type: {
        id: leave_type.id,
        name: leave_type.name
      },
      current_balance: {
        accrued_hours: current_accrued,
        used_hours: current_used,
        available_hours: current_available
      },
      projected_balance: {
        accrued_hours: projected_accrued,
        used_hours: future_used, # This is what will be used by the future date
        available_hours: projected_available
      },
      additional: {
        future_accrual: future_accrual,
        future_used: future_used
      }
    }
    
    render json: projected
  end

  private

  def leave_request_params
    # If leave_request params are nested under 'leave_request', use them
    # Otherwise, collect them from the top level
    if params[:leave_request].present?
      params_to_use = params.require(:leave_request)
    else
      # Create a new params object with only the leave_request-related keys
      params_to_use = ActionController::Parameters.new(
        start_date: params[:start_date],
        end_date: params[:end_date],
        start_time: params[:start_time],
        end_time: params[:end_time],
        requested_hours: params[:requested_hours],
        leave_type_id: params[:leave_type_id],
        user_id: params[:user_id],
        status: params[:status]
      )
    end
    
    # Permit the allowed attributes
    params_to_use.permit(:start_date, :end_date, :start_time, :end_time, :requested_hours, :leave_type_id, :user_id, :status)
  end
  
  # Optional: Method to handle record not found errors
  def record_not_found
    render json: { error: "Leave request not found" }, status: :not_found # status 404
  end
  
  # Helper method to restore leave balance when canceling a request
  def restore_leave_balance(leave_request)
    balance = current_user.leave_balances.find_by(leave_type_id: leave_request.leave_type_id)
    if balance
      balance.update(used_hours: (balance.used_hours || 0) - (leave_request.requested_hours || 0))
    end
  end
  
  # Helper method to deduct from leave balance when approving a request
  def deduct_from_leave_balance(leave_request)
    balance = current_user.leave_balances.find_by(leave_type_id: leave_request.leave_type_id)
    if balance
      balance.update(used_hours: (balance.used_hours || 0) + (leave_request.requested_hours || 0))
    end
  end
  
  # Update leave balance based on status changes
  def update_leave_balance_for_status_change(leave_request, old_status, new_status)
    # Define which statuses affect the balance
    affecting_statuses = ['approved', 'active', 'completed']
    
    # If changing FROM an affecting status TO a non-affecting status (e.g., approved → canceled)
    if affecting_statuses.include?(old_status) && !affecting_statuses.include?(new_status)
      restore_leave_balance(leave_request)
    
    # If changing FROM a non-affecting status TO an affecting status (e.g., pending → approved)
    elsif !affecting_statuses.include?(old_status) && affecting_statuses.include?(new_status)
      deduct_from_leave_balance(leave_request)
    end
  end
  
  # Calculate accrual between today and a future date
  def calculate_future_accrual(user, leave_type, future_date)
    # Skip calculation if no start date
    return 0 unless user.start_date.present?
    
    # Get the number of days between today and the future date
    # May 16 - May 2 = 14 days (turns into integer (it kept reading as a string))
    days_until_future = (future_date - Date.today).to_i
    
    # Calculate accrual based on the leave type's accrual period
    case leave_type.accrual_period.downcase #DOWNCASE IMPORTANT
      #.floor was important to show only integers rounded down incase it was a decimal... 
    when "biweekly" # 14 days
      #(14/14.0)*4.0 = 1*4 = 4.0 hours accrued
      (days_until_future / 14.0).floor * leave_type.accrual_rate
    when "monthly" # 30 days
      (days_until_future / 30.0).floor * leave_type.accrual_rate
    when "yearly" # 365 days
      (days_until_future / 365.0).floor * leave_type.accrual_rate
    else
      0
    end
  end
  
  # Calculate hours for a leave request
  def calculate_hours(start_date, end_date, start_time = nil, end_time = nil)
    # Ensure we're working with Date objects
    start_date = start_date.is_a?(Date) ? start_date : Date.parse(start_date.to_s)
    end_date = end_date.is_a?(Date) ? end_date : Date.parse(end_date.to_s)
    
    # Standard work day parameters
    hours_per_day = 8.0
    work_day_start_hour = 8  # 8:00am
    work_day_end_hour = 16   # 4:00pm
    
    # Log basic calculation info
    Rails.logger.info "LEAVE CALCULATION: #{start_date} to #{end_date}, times: #{start_time || '8:00'} to #{end_time || '16:00'}"
    
    # Handle single day requests
    if start_date == end_date
      # Skip weekend days
      return 0 if start_date.saturday? || start_date.sunday?
      
      # If specific times are provided, calculate hours between them
      if start_time.present? && end_time.present?
        begin
          # Parse times safely
          st = parse_time(start_time, start_date, work_day_start_hour)
          et = parse_time(end_time, start_date, work_day_end_hour, true)
          
          # Calculate hours for same day
          hours = [(et - st) / 3600.0, 0].max
          Rails.logger.info "Single day: #{hours} hours (#{st.strftime('%H:%M')} to #{et.strftime('%H:%M')})"
          return [hours, hours_per_day].min
        rescue => e
          Rails.logger.error "Time parsing error: #{e.message}"
          return hours_per_day # Default to full day if parsing fails
        end
      else
        # Full workday
        return hours_per_day
      end
    end
    
    # Handle multi-day requests
    total_hours = 0
    
    # First day (skip if weekend)
    first_day_hours = 0
    unless start_date.saturday? || start_date.sunday?
      if start_time.present?
        begin
          # Calculate hours from start time to end of work day
          st = parse_time(start_time, start_date, work_day_start_hour)
          day_end = Time.new(start_date.year, start_date.month, start_date.day, work_day_end_hour)
          hours = [(day_end - st) / 3600.0, 0].max
          first_day_hours = [hours, hours_per_day].min
        rescue => e
          Rails.logger.error "First day calculation error: #{e.message}"
          first_day_hours = hours_per_day
        end
      else
        first_day_hours = hours_per_day
      end
    end
    
    # Last day (skip if weekend)
    last_day_hours = 0
    unless end_date.saturday? || end_date.sunday?
      if end_time.present?
        begin
          # Calculate hours from start of work day to end time
          day_start = Time.new(end_date.year, end_date.month, end_date.day, work_day_start_hour)
          et = parse_time(end_time, end_date, work_day_end_hour, true)
          hours = [(et - day_start) / 3600.0, 0].max
          last_day_hours = [hours, hours_per_day].min
        rescue => e
          Rails.logger.error "Last day calculation error: #{e.message}"
          last_day_hours = hours_per_day
        end
      else
        last_day_hours = hours_per_day
      end
    end
    
    # Middle days (workdays only)
    middle_days = 0
    if (start_date + 1) <= (end_date - 1)
      (start_date + 1).upto(end_date - 1) do |date|
        middle_days += 1 unless date.saturday? || date.sunday?
      end
    end
    middle_days_hours = middle_days * hours_per_day
    
    # Calculate total
    total_hours = first_day_hours + middle_days_hours + last_day_hours
    
    # Log detailed breakdown
    Rails.logger.info "LEAVE BREAKDOWN: First day: #{first_day_hours}h, Middle days: #{middle_days_hours}h (#{middle_days} days), Last day: #{last_day_hours}h"
    Rails.logger.info "TOTAL HOURS: #{total_hours}"
    
    return total_hours
  end
  
  # Helper method to parse and normalize time input
  # is_end_time: true if this is an end time (for limiting to work day bounds)
  def parse_time(time_input, date, default_hour, is_end_time = false)
    # Handle both string and Time object inputs
    time_str = time_input.is_a?(Time) ? time_input.strftime("%H:%M") : time_input.to_s
    
    # Parse the time string
    parsed_time = time_str.include?(":") ? Time.parse(time_str) : Time.parse("#{time_str}:00")
    
    # Create time on the correct date
    result = Time.new(
      date.year, 
      date.month, 
      date.day, 
      parsed_time.hour, 
      parsed_time.min
    )
    
    # Enforce work day boundaries
    hour_with_minutes = result.hour + (result.min / 60.0)
    
    if !is_end_time && hour_with_minutes < 8
      # Start time before work day - adjust to 8am
      return Time.new(date.year, date.month, date.day, 8, 0)
    elsif is_end_time && hour_with_minutes > 16
      # End time after work day - adjust to 4pm
      return Time.new(date.year, date.month, date.day, 16, 0)
    end
    
    return result
  end
  
  # Returns true if the leave request's status affects the leave balance
  def affecting_balance?(leave_request)
    %w[approved active completed].include?(leave_request.status)
  end
  
  # Returns true if the leave request is being edited (any field except status is changed)
  def request_is_being_edited?(params)
    params[:start_date].present? || params[:end_date].present? || params[:start_time].present? || params[:end_time].present? || params[:requested_hours].present? || params[:leave_type_id].present?
  end
end
