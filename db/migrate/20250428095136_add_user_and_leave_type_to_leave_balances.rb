class AddUserAndLeaveTypeToLeaveBalances < ActiveRecord::Migration[8.0]
  def change
    add_reference :leave_balances, :user, null: false, foreign_key: true
    add_reference :leave_balances, :leave_type, null: false, foreign_key: true
  end
end
