class HealthController < ApplicationController
  skip_forgery_protection

  def live
    render json: {
      status:  "ok",
      service: "phr-web",
      env:     Rails.env,
      host:    ENV.fetch("HOSTNAME", "unknown"),
      time:    Time.current.iso8601
    }
  end

  # Readiness covers both backing stores this pod needs.
  def ready
    checks = {
      database: check { ActiveRecord::Base.connection.select_value("SELECT 1") },
      redis:    check { Sidekiq.redis(&:ping) }
    }

    healthy = checks.values.all? { |v| v == "up" }
    render json: { status: healthy ? "ready" : "unready" }.merge(checks),
           status: healthy ? :ok : :service_unavailable
  end

  private

  def check
    yield
    "up"
  rescue StandardError => e
    Rails.logger.warn("readiness check failed: #{e.class}: #{e.message}")
    "down"
  end
end
