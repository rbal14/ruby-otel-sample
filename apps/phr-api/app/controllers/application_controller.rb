class ApplicationController < ActionController::API
  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
  rescue_from ActionController::ParameterMissing, with: :render_bad_request

  private

  def render_not_found(error)
    render json: { error: "not_found", message: error.message }, status: :not_found
  end

  def render_bad_request(error)
    render json: { error: "bad_request", message: error.message }, status: :bad_request
  end

  # Pagination kept intentionally simple: page/per_page, capped so a stray
  # load generator cannot ask MySQL for the whole table.
  def pagination
    page     = [params.fetch(:page, 1).to_i, 1].max
    per_page = params.fetch(:per_page, 25).to_i.clamp(1, 100)
    [page, per_page]
  end
end
