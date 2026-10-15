require "sidekiq"

REDIS_URL = ENV.fetch("REDIS_URL", "redis://localhost:6379/0")

Sidekiq.configure_server do |config|
  config.redis = { url: REDIS_URL }
  config.concurrency = Integer(ENV.fetch("SIDEKIQ_CONCURRENCY", "5"))
end

Sidekiq.configure_client do |config|
  config.redis = { url: REDIS_URL }
end
