class UserPolicy < ApplicationPolicy
  # Only allow users to view their own profile
  def show?
    user.present? && user.id == record.id
  end

  # Only allow users to update their own profile
  def update?
    user.present? && user.id == record.id
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(id: user.id)
    end
  end
end
