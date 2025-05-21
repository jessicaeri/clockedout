class AddOneTimeAccrualToLeaveTypes < ActiveRecord::Migration[8.0]
  def change
    add_column :leave_types, :one_time_accrual, :boolean, default: false, null: false, comment: "If true, this leave type doesn't accrue regularly but can have hours added manually"
  end
end
