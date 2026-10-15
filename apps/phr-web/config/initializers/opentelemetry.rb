require "opentelemetry/sdk"
require "opentelemetry/exporter/otlp"
require "opentelemetry/instrumentation/all"

OpenTelemetry::SDK.configure do |c|
    # service.name, the endpoint, and the protocol come from OTEL_* in the
    # environment, so the same image can run as more than one service.
    c.use_all(
      # Kubelet probes /health and /ready every 10-20s on two replicas, and
      # the load generator adds more. Left traced, they would dominate.
      "OpenTelemetry::Instrumentation::Rack" => {
        untraced_endpoints: ["/health", "/ready"]
      }
    )
end