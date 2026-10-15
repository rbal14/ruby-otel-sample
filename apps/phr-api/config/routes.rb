Rails.application.routes.draw do
  # Probes. /health never touches MySQL (liveness), /ready does (readiness).
  get "/health", to: "health#live"
  get "/ready",  to: "health#ready"

  namespace :api do
    namespace :v1 do
      resources :leads, only: %i[index show create update] do
        collection do
          get :stats
        end
      end

      resources :appointments, only: %i[index show create update]

      # Deliberate misbehaviour, for validating what Dynatrace surfaces.
      scope :simulate do
        get "slow_query", to: "simulations#slow_query"
        get "n_plus_one", to: "simulations#n_plus_one"
        get "table_scan", to: "simulations#table_scan"
        get "error",      to: "simulations#error"
        get "cpu",        to: "simulations#cpu"
      end
    end
  end

  root to: "health#live"
end
