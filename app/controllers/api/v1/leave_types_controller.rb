class Api::V1::LeaveTypesController < ApplicationController
  before_action :authenticate, only: [:create, :show :update, :destroy]

  def create
    leave_type = LeaveType.new(leave_type_params)
    leave_type.user = current_user #current user is creating leave_type to THEIR account
    if leave_type.save
      render json: { message: 'Leave type created successfully' }, status: :created
    else
      render json: { errors: leave_type.errors }, status: :unprocessable_entity
    end
  end

  def show
    leave_type = LeaveType.find(params[:id])
    render json: leave_type
  end     

  def update
    leave_type = LeaveType.find(params[:id])
    leave_type.update(leave_type_params)
    render json: { message: 'Leave type updated successfully' }, status: :ok
  end

  def destroy
    leave_type = LeaveType.find(params[:id])
    leave_type.destroy
    render json: { message: 'Leave type deleted successfully' }, status: :ok
  end

  private

  def leave_type_params
    params.require(:leave_type).permit(:type, :accrual_rate, :accrual_period)
  end
end
