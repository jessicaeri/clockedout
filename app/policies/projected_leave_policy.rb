class ProjectedLeavePolicy < ApplicationPolicy
  def create?
    user.present? # all users can create their own projected leave request
  end 
  
  def show?
    # current user can view only their own projected leave request
    user.present? && user.id == record.user_id
  end

  def update?
    # current user can update only their own projected leave request
    user.present? && user.id == record.user_id
  end

  def destroy?
    # current user can delete only their own projected leave request
    user.present? && user.id == record.user_id
  end

  #Only show the user's projected leave requests
  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(user: user)
    end
  end
end
