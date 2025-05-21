Rails.application.routes.draw do
  post '/signup', to: 'users#create'
  get '/me', to: 'users#me'
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
          # GET /api/v1/leave_balances/summary
          # http :3000/api/v1/leave_balances/summary
          get :summary  
          get :refresh_projections  # New endpoint to force refresh of all projections
        end
        
        # Add a custom route to reset a leave balance
        member do
          # POST /api/v1/leave_balances/:id/reset
          # http POST :3000/api/v1/leave_balances/:id/reset
          post :reset
        end
      end

      # Routes provided by resources :leave_balances:
      # GET    /api/v1/leave_balances          -> index
      # POST   /api/v1/leave_balances          -> create
      # GET    /api/v1/leave_balances/:id      -> show
      # PATCH  /api/v1/leave_balances/:id      -> update
      # DELETE /api/v1/leave_balances/:id      -> destroy

      resources :leave_requests do
        member do
          post :submit    # Submit a planned request for approval
          post :approve   # Approve a pending request
          post :cancel    # Cancel an existing request
          get :recalculate_hours  # Recalculate hours for a leave request with the improved algorithm
        end
        
        collection do
          get :projected_balance  # Calculate projected balance as of a future date
          get :calculate_hours    # Calculate leave hours without creating a leave request
        end
      end
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
      
      # Note: Projected requests functionality is now handled by leave_requests with status='planned'
      # The projected_requests routes and controller have been removed
    end
  end
end
