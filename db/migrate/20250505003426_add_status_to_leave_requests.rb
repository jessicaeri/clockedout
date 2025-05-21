class AddStatusToLeaveRequests < ActiveRecord::Migration[8.0]
  def change
    add_column :leave_requests, :status, :string, null: false, default: 'planned'
  end
end
