class CreateLeaveTypes < ActiveRecord::Migration[8.0]
  def change
    create_table :leave_types do |t|
      t.string :type
      t.decimal :accrual_rate
      t.string :accrual_period

      t.timestamps
    end
  end
end
