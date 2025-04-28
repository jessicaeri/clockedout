class LeaveBalance < ApplicationRecord
  belongs_to :user 
  belongs_to :leave_type

  validates :accrude_hours, presence: true
end
