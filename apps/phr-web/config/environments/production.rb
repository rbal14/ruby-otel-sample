require "active_support/core_ext/integer/time"

Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = true

  # Flip RAILS_SHOW_EXCEPTIONS=true on a pod when you want the Rails error page
  # instead of the generic 500, which is handy while wiring up the POC.
  config.consider_all_requests_local = ENV["RAILS_SHOW_EXCEPTIONS"] == "true"
  config.action_dispatch.show_exceptions = :all

  # There is no asset pipeline here, but public/ still holds the error pages.
  config.public_file_server.enabled = true
  config.public_file_server.headers = { "Cache-Control" => "public, max-age=3600" }

  config.logger = ActiveSupport::TaggedLogging.new(
    ActiveSupport::Logger.new($stdout).tap { |logger| logger.formatter = ::Logger::Formatter.new }
  )
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")
  config.log_tags = [:request_id]
  config.active_support.report_deprecations = false

  config.active_record.dump_schema_after_migration = false

  config.i18n.fallbacks = true
  config.force_ssl = false

  # Rails reads SECRET_KEY_BASE from the environment on its own; it is supplied
  # by the phr-web-secrets Secret in Kubernetes. Boot fails without it.
end
