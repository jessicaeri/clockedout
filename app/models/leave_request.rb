class LeaveRequest < ApplicationRecord
  belongs_to :user 
  belongs_to :leave_type

  validates :start_date, presence: true
  validates :end_date, presence: true
  validates :requested_hours, presence: true

end
