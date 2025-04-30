class LeaveTypePolicy < ApplicationPolicy
  # Remove custom initializer - it's already defined in ApplicationPolicy
  # attr_reader :user
  #
  # def initialize(user)
  #   @user = user
  # end
  
  def create?
    user.present? # all users can create their own leave type
  end 
  
  def show?
    # current user can view only their own leave type
    user.present? && user.id == record.user_id
  end

  def update?
    # current user can update only their own leave type
    user.present? && user.id == record.user_id
  end

  def destroy?
    # current user can delete only their own leave type
    user.present? && user.id == record.user_id
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(user: user)
    end
  end
end
