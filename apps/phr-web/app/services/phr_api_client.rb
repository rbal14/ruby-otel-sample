require "net/http"
require "uri"
require "json"

# Thin HTTP client for phr-api. Uses Net::HTTP from stdlib on purpose: it is
# what a lot of long-lived Rails code actually uses, and it is one of the
# libraries an auto-instrumentation agent is expected to pick up.
class PhrApiClient
  class Error < StandardError
    attr_reader :status, :body

    def initialize(message, status: nil, body: nil)
      super(message)
      @status = status
      @body = body
    end
  end

  class TimeoutError < Error; end

  def initialize(base_url: nil, timeout: nil)
    @base_url = (base_url || Rails.configuration.x.api_base_url).to_s.chomp("/")
    @timeout  = timeout || Rails.configuration.x.api_timeout
  end

  def leads(status: nil, source: nil, page: 1, per_page: 25)
    get("/api/v1/leads", status: status, source: source, page: page, per_page: per_page)
  end

  def lead(id)
    get("/api/v1/leads/#{id}")
  end

  def create_lead(attributes)
    post("/api/v1/leads", lead: attributes)
  end

  def update_lead(id, attributes)
    patch("/api/v1/leads/#{id}", lead: attributes)
  end

  def appointments(status: nil, page: 1, per_page: 25)
    get("/api/v1/appointments", status: status, page: page, per_page: per_page)
  end

  def stats
    get("/api/v1/leads/stats")
  end

  def slow_query(seconds: 2)
    get("/api/v1/simulate/slow_query", seconds: seconds)
  end

  def simulate_error
    get("/api/v1/simulate/error")
  end

  private

  def get(path, query = {})
    uri = build_uri(path, query)
    request(Net::HTTP::Get.new(uri), uri)
  end

  def post(path, payload)
    uri = build_uri(path)
    req = Net::HTTP::Post.new(uri)
    req.body = payload.to_json
    request(req, uri)
  end

  def patch(path, payload)
    uri = build_uri(path)
    req = Net::HTTP::Patch.new(uri)
    req.body = payload.to_json
    request(req, uri)
  end

  def build_uri(path, query = {})
    uri = URI.parse("#{@base_url}#{path}")
    compacted = query.compact
    uri.query = URI.encode_www_form(compacted) if compacted.any?
    uri
  end

  def request(req, uri)
    req["Content-Type"] = "application/json"
    req["Accept"] = "application/json"
    req["X-Request-Source"] = "phr-web"

    response = Net::HTTP.start(
      uri.hostname,
      uri.port,
      use_ssl: uri.scheme == "https",
      open_timeout: @timeout,
      read_timeout: @timeout
    ) { |http| http.request(req) }

    handle(response, uri)
  rescue Net::OpenTimeout, Net::ReadTimeout => e
    raise TimeoutError.new("phr-api timed out after #{@timeout}s calling #{uri.path}: #{e.class}")
  rescue Errno::ECONNREFUSED, SocketError => e
    raise Error.new("phr-api unreachable at #{@base_url}: #{e.class}: #{e.message}")
  end

  def handle(response, uri)
    body = response.body.presence
    parsed = body ? JSON.parse(body) : {}

    return parsed if response.is_a?(Net::HTTPSuccess)

    raise Error.new(
      "phr-api returned #{response.code} for #{uri.path}",
      status: response.code.to_i,
      body: parsed
    )
  rescue JSON::ParserError
    raise Error.new("phr-api returned unparseable body (#{response.code}) for #{uri.path}",
                    status: response.code.to_i, body: response.body)
  end
end
