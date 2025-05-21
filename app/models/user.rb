class User < ApplicationRecord
  has_many :leave_types
  has_many :leave_balances 
  has_many :leave_requests
  has_many :projected_requests

  has_secure_password

  validates :email, presence: true, uniqueness: true
  validates :name, presence: true
  # Only validate password presence for new records, with no minimum length
  validates :password, presence: true, on: :create
  
  # Only validate password_confirmation on create or when password is changing
  validates :password_confirmation, presence: true, if: -> { password.present? && new_record? }
  validates :start_date, presence: true

  # Convert email to lowercase before saving
  before_validation :downcase_email

  private

  def downcase_email
    self.email = email.to_s.downcase if email.present?
  end
  
end
