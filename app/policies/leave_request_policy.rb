class LeaveRequestPolicy < ApplicationPolicy
  def create?
    user.present? # all users can create their own leave request
  end 
  
  def show?
    # current user can view only their own leave request
    user.present? && user.id == record.user_id
  end

  def update?
    # current user can update only their own leave request
    user.present? && user.id == record.user_id
  end

  def destroy?
    # current user can delete only their own leave request
    user.present? && user.id == record.user_id
  end
  
  # Add missing methods for special actions
  def submit?
    # User can submit their own leave request
    user.present? && user.id == record.user_id
  end
  
  def approve?
    # For now, allow the user to approve their own leave request
    # In a real-world scenario, this would typically be restricted to managers or admins
    user.present? && user.id == record.user_id
  end
  
  def cancel?
    # User can cancel their own leave request
    user.present? && user.id == record.user_id
  end
  
  def recalculate_hours?
    # User can recalculate hours for their own leave request
    user.present? && user.id == record.user_id
  end

  #Only show the user's leave requests
  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(user: user)
    end
  end
end
