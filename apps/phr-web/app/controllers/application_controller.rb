class ApplicationController < ActionController::Base
  rescue_from PhrApiClient::Error, with: :handle_api_error

  private

  # phr-api being down should show as a degraded page rather than a bare 500,
  # so the failure is attributable to the downstream service.
  def handle_api_error(error)
    Rails.logger.error("phr-api call failed: #{error.class}: #{error.message}")

    @error = error
    render "shared/api_error", status: :bad_gateway
  end

  def page_params
    page     = [params.fetch(:page, 1).to_i, 1].max
    per_page = params.fetch(:per_page, 25).to_i.clamp(1, 100)
    [page, per_page]
  end

  def api_client
    @api_client ||= PhrApiClient.new
  end
end
