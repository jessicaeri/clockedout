class MigrateProjectedRequestsToLeaveRequests < ActiveRecord::Migration[8.0]
  def up
    # First make sure the status column exists on leave_requests
    unless column_exists?(:leave_requests, :status)
      add_column :leave_requests, :status, :string, null: false, default: 'planned'
    end
    
    # Get all projected requests
    projected_count = execute("SELECT COUNT(*) FROM projected_requests").first["count"].to_i
    puts "Migrating #{projected_count} projected requests to leave_requests with status='planned'"
    
    # For each record in projected_requests, create a corresponding record in leave_requests
    execute(<<-SQL)
      INSERT INTO leave_requests (
        start_date, 
        end_date, 
        requested_hours, 
        user_id, 
        leave_type_id, 
        created_at, 
        updated_at, 
        status
      )
      SELECT 
        start_date, 
        end_date, 
        requested_hours, 
        user_id, 
        leave_type_id, 
        created_at, 
        updated_at, 
        'planned' as status
      FROM projected_requests
    SQL
    
    # Report completion
    leave_count = execute("SELECT COUNT(*) FROM leave_requests WHERE status = 'planned'").first["count"].to_i
    puts "Migration complete. #{leave_count} leave requests with status='planned'"
  end

  def down
    # This migration is not reversible as it would be difficult to determine
    # which leave_requests with status='planned' came from projected_requests
    raise ActiveRecord::IrreversibleMigration
  end
end
