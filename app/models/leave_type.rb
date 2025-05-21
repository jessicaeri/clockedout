class LeaveType < ApplicationRecord
  belongs_to :user
  
  has_many :leave_balances, dependent: :destroy 
  has_many :leave_requests, dependent: :destroy

  validates :name, presence: true
  validates :accrual_rate, presence: true
  
  # Validate that accrual_period is present unless this is a one-time accrual type
  validates :accrual_period, presence: true, unless: :one_time_accrual
  
  # Method to check if this is a regular accruing leave type
  def regular_accrual?
    !one_time_accrual
  end
end
