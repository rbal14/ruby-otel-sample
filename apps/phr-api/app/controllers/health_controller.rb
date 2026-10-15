class HealthController < ApplicationController
  # Liveness: process is up. Deliberately does not touch MySQL, otherwise a
  # database blip restarts every application pod in the namespace.
  def live
    render json: {
      status:  "ok",
      service: "phr-api",
      env:     Rails.env,
      host:    ENV.fetch("HOSTNAME", "unknown"),
      time:    Time.current.iso8601
    }
  end

  # Readiness: this pod can actually serve traffic, which means MySQL answers.
  def ready
    ActiveRecord::Base.connection.select_value("SELECT 1")
    render json: { status: "ready", database: "up" }
  rescue StandardError => e
    render json: { status: "unready", database: "down", message: e.message },
           status: :service_unavailable
  end
end
