# config/initializers/cors.rb

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins 'http://localhost:5173'  # Your React frontend origin

    resource '*',
      headers: :any,
      methods: [:get, :post, :patch, :put, :delete, :options, :head],
      credentials: true  # allows cookies / tokens if you're using them
  end
end