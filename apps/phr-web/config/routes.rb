Rails.application.routes.draw do
  root to: "dashboard#index"

  get "/health", to: "health#live"
  get "/ready",  to: "health#ready"

  resources :customers, only: %i[index show new create]
  resources :projects,  only: %i[index show]

  # Read models served by phr-api over HTTP.
  resources :leads,        only: %i[index show]
  resources :appointments, only: %i[index]

  # CSRF-exempt JSON entry point. Stands in for the marketing-site webhook that
  # drops new leads into the platform, and is what the load generator calls.
  namespace :internal do
    post "leads", to: "simulations#create_lead"
  end

  # Deliberate misbehaviour for validating observability. See phr-api for the
  # database-side equivalents.
  scope :debug do
    get "slow",       to: "debug#slow"
    get "error",      to: "debug#error"
    get "n_plus_one", to: "debug#n_plus_one"
    get "downstream", to: "debug#downstream"
  end

  # Sidekiq's dashboard is genuinely useful during the POC, but never let a
  # missing/incompatible gem take the whole app down at boot.
  begin
    require "sidekiq/web"
    mount Sidekiq::Web => "/sidekiq"
  rescue LoadError, StandardError => e
    Rails.logger&.warn("sidekiq/web not mounted: #{e.class}: #{e.message}")
  end
end
