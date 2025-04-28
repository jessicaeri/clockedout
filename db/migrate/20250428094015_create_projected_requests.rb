class CreateProjectedRequests < ActiveRecord::Migration[8.0]
  def change
    create_table :projected_requests do |t|
      t.date :start_date
      t.date :end_date
      t.decimal :requested_hours

      t.timestamps
    end
  end
end
