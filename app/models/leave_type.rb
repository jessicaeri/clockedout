class LeaveType < ApplicationRecord
  belongs_to :user
  
  has_many :leave_balances 
  has_many :leave_requests
  has_many :projected_requests

  validates :name, presence: true
  validates :accrual_rate, presence: true
end
