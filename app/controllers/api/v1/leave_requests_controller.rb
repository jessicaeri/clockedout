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
    authorize @leave_request #LeaveRequestPolicy#create?
    if @leave_request.save
      render json: { message: 'Leave request created successfully' }, status: :created
    else
      render json: { errors: @leave_request.errors }, status: :unprocessable_entity
    end
  end

  # GET /api/v1/leave_requests
  # http :3000/api/v1/leave_requests
  def index
    @leave_requests = policy_scope(LeaveRequest)
    render json: @leave_requests
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
    authorize @leave_request #LeaveRequestPolicy#update?
    if @leave_request.update(leave_request_params)
      render json: { message: 'Leave request updated successfully' }, status: :ok
    else
      render json: { errors: @leave_request.errors }, status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/leave_requests/:id
  # http DELETE :3000/api/v1/leave_requests/:id
  def destroy
    @leave_request = LeaveRequest.find(params[:id])
    authorize @leave_request #LeaveRequestPolicy#destroy?
    @leave_request.destroy
    render json: { message: 'Leave request deleted successfully' }, status: :ok
    head :no_content # status 204 No Content - Standard practice for successful delete
  end

  private

  def leave_request_params
    params.require(:leave_request).permit(:start_date, :end_date, :requested_hours)
  end

  # Optional: Method to handle record not found errors
  def record_not_found
    render json: { error: "Leave request not found" }, status: :not_found # status 404
  end
end
