require "active_support/core_ext/integer/time"

Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = false
  config.cache_classes = true
  config.consider_all_requests_local = true
  config.action_dispatch.show_exceptions = :none
  config.active_support.deprecation = :stderr
end
