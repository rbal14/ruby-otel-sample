class ApplicationJob < ActiveJob::Base
  retry_on PhrApiClient::TimeoutError, wait: :polynomially_longer, attempts: 3
  discard_on ActiveJob::DeserializationError
end
