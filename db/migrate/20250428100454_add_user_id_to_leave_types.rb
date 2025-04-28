class AddUserIdToLeaveTypes < ActiveRecord::Migration[8.0]
  def change
    add_reference :leave_types, :user, null: false, foreign_key: true
  end
end
