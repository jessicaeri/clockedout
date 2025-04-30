class User < ApplicationRecord
  has_many :leave_types
  has_many :leave_balances 
  has_many :leave_requests
  has_many :projected_requests

  has_secure_password

  validates :email, presence: true, uniqueness: true
  validates :name, presence: true
  validates :password, presence: true
  validates :password_confirmation, presence: true
  validates :start_date, presence: true

  
end
