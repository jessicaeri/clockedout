Rails.application.routes.draw do
  post '/signup', to: 'users#create'
  post '/login', to: 'sessions#create'

  namespace :api do
    namespace :v1 do
      resources :users
      # SHOW - GET /api/v1/users/:id
      # http :3000/api/v1/users/:id

      # UPDATE - PATCH /api/v1/users/:id
      # http PATCH :3000/api/v1/users/:id \
      #   user[name]='John Doe' \
      #   user[email]='john@example.com' \
      #   user[password]='password'

      # LOGIN - POST /api/v1/login
      # http POST :3000/api/v1/login \
      #   email='john@example.com' \
      #   password='password'

      resources :leave_types
      # CREATE - POST /api/v1/leave_types
      # http POST :3000/api/v1/leave_types \
      #   leave_type[type]='Vacation' \
      #   leave_type[accrual_rate]='1.0' \
      #   leave_type[accrual_period]='Year'

      # SHOW - GET /api/v1/leave_types/:id
      # http :3000/api/v1/leave_types/:id
      
      # UPDATE - PATCH /api/v1/leave_types/:id
      # http PATCH :3000/api/v1/leave_types/:id \
      #   leave_type[type]='Vacation' \
      #   leave_type[accrual_rate]='1.0' \
      #   leave_type[accrual_period]='Year'

      # DELETE - DELETE /api/v1/leave_types/:id
      # http DELETE :3000/api/v1/leave_types/:id
      resources :leave_balances do
        # Add a custom route for summary at the collection level
        collection do
          get :summary  # GET /api/v1/leave_balances/summary
        end
      end
      #SHOW - GET /api/v1/leave_balances/:id
      #http :3000/api/v1/leave_balances/:id
      
      #UPDATE - PATCH /api/v1/leave_balances/:id
      #http PATCH :3000/api/v1/leave_balances/:id \\
      #  leave_balance[accrued_hours]='8.0' \\
      #  leave_balance[used_hours]='8.0'  
      
      resources :leave_requests
      # CREATE - POST /api/v1/leave_requests
      # http POST :3000/api/v1/leave_requests \
      #   leave_request[start_date]='2025-07-01' \
      #   leave_request[end_date]='2025-07-01' \
      #   leave_request[requested_hours]='8.0'
      
      # SHOW - GET /api/v1/leave_requests/:id
      # http :3000/api/v1/leave_requests/:id
      
      # UPDATE - PATCH /api/v1/leave_requests/:id
      # http PATCH :3000/api/v1/leave_requests/:id \
      #   leave_request[start_date]='2025-07-01' \
      #   leave_request[end_date]='2025-07-01' \
      #   leave_request[requested_hours]='8.0'
      
      # DELETE - DELETE /api/v1/leave_requests/:id
      # http DELETE :3000/api/v1/leave_requests/:id
      
      resources :projected_requests
      # CREATE - POST /api/v1/projected_requests
      # http POST :3000/api/v1/projected_requests \
      #   projected_request[start_date]='2025-07-01' \
      #   projected_request[end_date]='2025-07-01' \
      #   projected_request[requested_hours]='8.0'
      
      # SHOW - GET /api/v1/projected_requests/:id
      # http :3000/api/v1/projected_requests/:id
      
      # UPDATE - PATCH /api/v1/projected_requests/:id
      # http PATCH :3000/api/v1/projected_requests/:id \
      #   projected_request[start_date]='2025-07-01' \
      #   projected_request[end_date]='2025-07-01' \
      #   projected_request[requested_hours]='8.0'
      
      # DELETE - DELETE /api/v1/projected_requests/:id
      # http DELETE :3000/api/v1/projected_requests/:id 
    end
  end
end
