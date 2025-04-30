class Api::V1::ProjectedRequestsController < ApplicationController
  before_action :authorize_request #authorizes user to update THEIR own projected leave request 
  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found

  # POST /api/v1/projected_requests
  # http POST :3000/api/v1/projected_requests \
  #   projected_request[start_date]='2025-07-01' \
  #   projected_request[end_date]='2025-07-01' \
  #   projected_request[requested_hours]='8.0'
  def create
    @projected_request = ProjectedRequest.new(projected_request_params)
    authorize @projected_request #ProjectedRequestPolicy#create?  
    if @projected_request.save
      render json: { message: 'Projected request created successfully' }, status: :created
    else
      render json: { errors: @projected_request.errors }, status: :unprocessable_entity
    end
  end

  # GET /api/v1/projected_requests
  # http :3000/api/v1/projected_requests
  def index
    @projected_requests = policy_scope(ProjectedRequest)
    render json: @projected_requests
  end

  # GET /api/v1/projected_requests/:id
  # http :3000/api/v1/projected_requests/:id
  def show
    @projected_request = ProjectedRequest.find(params[:id])
    authorize @projected_request #ProjectedRequestPolicy#show?
    render json: @projected_request
  end     

  # PATCH /api/v1/projected_requests/:id
  # http PATCH :3000/api/v1/projected_requests/:id \
  #   projected_request[start_date]='2025-07-01' \
  #   projected_request[end_date]='2025-07-01' \
  #   projected_request[requested_hours]='8.0'
  def update
    @projected_request = ProjectedRequest.find(params[:id])
    authorize @projected_request #ProjectedRequestPolicy#update?
    if @projected_request.update(projected_request_params)
      render json: { message: 'Projected request updated successfully' }, status: :ok
    else
      render json: { errors: @projected_request.errors }, status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/projected_requests/:id
  # http DELETE :3000/api/v1/projected_requests/:id
  def destroy
    @projected_request = ProjectedRequest.find(params[:id])
    authorize @projected_request #ProjectedRequestPolicy#destroy?
    @projected_request.destroy
    render json: { message: 'Projected request deleted successfully' }, status: :ok
    head :no_content # status 204 No Content - Standard practice for successful delete
  end

  private

  def projected_request_params
    params.require(:projected_request).permit(:start_date, :end_date, :requested_hours)
  end

  # Optional: Method to handle record not found errors
  def record_not_found
    render json: { error: "Projected request not found" }, status: :not_found # status 404
  end
end
