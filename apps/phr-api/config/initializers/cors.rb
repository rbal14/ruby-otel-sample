# The web front end calls this service from inside the cluster, but leaving CORS
# open makes it easy to poke at the API from a browser during the POC.
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins "*"
    resource "*", headers: :any, methods: %i[get post patch put delete options head]
  end
end
