class AddTimeFieldsToLeaveRequests < ActiveRecord::Migration[8.0]
  def change
    add_column :leave_requests, :start_time, :time
    add_column :leave_requests, :end_time, :time
  end
end
