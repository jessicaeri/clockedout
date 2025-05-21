class DropProjectedRequests < ActiveRecord::Migration[8.0]
  def up
    drop_table :projected_requests
  end

  def down
    create_table :projected_requests do |t|
      t.date :start_date
      t.date :end_date
      t.decimal :requested_hours
      t.references :user, null: false, foreign_key: true
      t.references :leave_type, null: false, foreign_key: true

      t.timestamps
    end
  end
end
