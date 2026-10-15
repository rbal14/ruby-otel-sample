require "active_support/core_ext/integer/time"

Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = true

  config.consider_all_requests_local = ENV["RAILS_SHOW_EXCEPTIONS"] == "true"
  config.action_dispatch.show_exceptions = :all

  config.public_file_server.enabled = false

  # Log to stdout as a single stream so the container runtime (and any log
  # collector running on the cluster) picks everything up.
  config.logger = ActiveSupport::TaggedLogging.new(
    ActiveSupport::Logger.new($stdout).tap { |logger| logger.formatter = ::Logger::Formatter.new }
  )
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")
  config.log_tags = [:request_id]
  config.active_support.report_deprecations = false

  config.active_record.dump_schema_after_migration = false
  config.active_record.verify_foreign_keys_for_fixtures = false

  config.i18n.fallbacks = true
  config.force_ssl = false
end
