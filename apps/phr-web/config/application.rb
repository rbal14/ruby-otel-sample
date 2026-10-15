require_relative "boot"

require "rails"
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "action_view/railtie"

Bundler.require(*Rails.groups)

module PhrWeb
  class Application < Rails::Application
    config.load_defaults 7.1

    config.time_zone = "UTC"
    config.active_record.default_timezone = :utc

    # Background work goes through Sidekiq/Redis, the way most Rails shops run it.
    config.active_job.queue_adapter = :sidekiq

    # Reached over a LoadBalancer IP or an arbitrary ingress hostname during the
    # POC, so do not second-guess the Host header.
    config.hosts.clear

    # No asset pipeline in this sandbox -- styles are inlined in the layout so
    # the image build stays a single `bundle install` with no Node toolchain.
    config.generators.system_tests = nil

    # Base URL of the leads/appointments service.
    config.x.api_base_url = ENV.fetch("PHR_API_URL", "http://localhost:3001")
    config.x.api_timeout  = Integer(ENV.fetch("PHR_API_TIMEOUT_SECONDS", "5"))
  end
end
