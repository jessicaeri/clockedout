class RenameTypeToNameInLeaveTypes < ActiveRecord::Migration[8.0]
  def change
    rename_column :leave_types, :type, :name
  end
end
