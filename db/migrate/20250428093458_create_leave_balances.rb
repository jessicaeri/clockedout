class CreateLeaveBalances < ActiveRecord::Migration[8.0]
  def change
    create_table :leave_balances do |t|
      t.decimal :accrued_hours
      t.decimal :used_hours

      t.timestamps
    end
  end
end
