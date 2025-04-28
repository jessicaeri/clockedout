class AddUserAndLeaveTypeToProjectedRequests < ActiveRecord::Migration[8.0]
  def change
    add_reference :projected_requests, :user, null: false, foreign_key: true
    add_reference :projected_requests, :leave_type, null: false, foreign_key: true
  end
end
