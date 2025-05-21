class LeaveRequest < ApplicationRecord
  # Status constants
  STATUS_PLANNED = 'planned'     # Projected/future request that doesn't affect balance
  STATUS_PENDING = 'pending'     # Submitted but not approved
  STATUS_APPROVED = 'approved'   # Approved but not yet taken
  STATUS_ACTIVE = 'active'       # Currently on leave
  STATUS_COMPLETED = 'completed' # Leave period has passed
  STATUS_CANCELED = 'canceled'   # Request was canceled
  
  belongs_to :user 
  belongs_to :leave_type

  validates :start_date, presence: true
  validates :end_date, presence: true
  validates :requested_hours, presence: true
  validates :status, presence: true, inclusion: { 
    in: [STATUS_PLANNED, STATUS_PENDING, STATUS_APPROVED, STATUS_ACTIVE, STATUS_COMPLETED, STATUS_CANCELED],
    message: "%{value} is not a valid status"
  }
  
  # Custom validation to check available balance
  validate :has_enough_leave_balance, on: [:create, :update]
  
  # Set default status if not provided
  before_validation :set_default_status, on: :create
  
  # Scopes for different statuses
  scope :planned, -> { where(status: STATUS_PLANNED) }
  scope :pending, -> { where(status: STATUS_PENDING) }
  scope :approved, -> { where(status: STATUS_APPROVED) }
  scope :active, -> { where(status: STATUS_ACTIVE) }
  scope :completed, -> { where(status: STATUS_COMPLETED) }
  scope :canceled, -> { where(status: STATUS_CANCELED) }
  
  # Only deduct from leave balance for approved/active/completed requests
  scope :affecting_balance, -> { where(status: [STATUS_APPROVED, STATUS_ACTIVE, STATUS_COMPLETED]) }
  
  # Projected requests that don't affect balance (same as planned)
  scope :projected, -> { where(status: STATUS_PLANNED) }
  
  # Check if hours are available in leave balance
  def has_enough_leave_balance
    # This validation has been disabled - users can now request leave that exceeds their available balance
    # Just log the request details for informational purposes
    
    # Find the user's leave balance for this leave type
    balance = LeaveBalance.find_by(user_id: user_id, leave_type_id: leave_type_id)
    
    if balance.present?
      # Log current balance information for debugging
      accrued = balance.accrued_hours || 0
      used = balance.used_hours || 0
      available_hours = accrued - used
      
      Rails.logger.info "LEAVE REQUEST: #{requested_hours} hours requested, available balance: #{available_hours} hours"
      
      # No validation errors are added - all requests are allowed regardless of balance
    else
      Rails.logger.info "LEAVE REQUEST: #{requested_hours} hours requested (no balance record found)"
    end
    
    # Always return true - validation is disabled
    return true
  end

  private
  
  def set_default_status
    self.status ||= STATUS_PLANNED
  end
end
