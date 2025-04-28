class User < ApplicationRecord
  has_many :leave_types
  has_many :leave_balances 
  has_many :leave_requests
  has_many :projected_requests

  has_secure_password

  validates :email, presence: true, uniqueness: true
  validates :name, presence: true

end
