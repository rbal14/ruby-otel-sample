require_relative "boot"

require "rails"
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "action_view/railtie"

Bundler.require(*Rails.groups)

module PhrApi
  class Application < Rails::Application
    config.load_defaults 7.1

    # Leads / appointments service: JSON only, no views, no cookies, no sessions.
    config.api_only = true
    config.time_zone = "UTC"
    config.active_record.default_timezone = :utc

    # Everything the container needs comes from the environment so the same
    # image runs in docker compose and in AKS.
    config.hosts.clear
  end
end
