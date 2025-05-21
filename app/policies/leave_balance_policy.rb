class LeaveBalancePolicy < ApplicationPolicy
  # Remove the custom initializer and attr_reader because they're already defined in ApplicationPolicy
  # attr_reader :user
  #
  # def initialize(user)
  #   @user = user
  # end
  
  def show?
    # Check if user can view this leave_balance
    user.present? && user.id == record.user_id
  end

  def create?
    # Any authenticated user can create a leave balance for themselves
    user.present? && user.id == record.user_id
  end

  def update?
    # Check if user can update this leave_balance
    user.present? && user.id == record.user_id
  end

  def destroy?
    # Only allow users to delete their own leave balances
    user.present? && user.id == record.user_id
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(user: user)
    end
  end
end
