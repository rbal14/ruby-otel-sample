# Application-side misbehaviour. The database-side equivalents live in
# phr-api's SimulationsController.
class DebugController < ApplicationController
  skip_forgery_protection

  class SimulatedFailure < StandardError; end

  # GET /debug/slow?seconds=2 -- slow because the app is sleeping, not the DB.
  def slow
    seconds = params.fetch(:seconds, 2).to_f.clamp(0.1, 15.0)
    sleep seconds
    render json: { simulated: "slow_response", seconds: seconds }
  end

  # GET /debug/error
  def error
    raise SimulatedFailure, "simulated unhandled exception in phr-web (request_id=#{request.request_id})"
  end

  # GET /debug/n_plus_one?limit=50 -- one query per customer for its projects.
  def n_plus_one
    limit = params.fetch(:limit, 50).to_i.clamp(1, 500)

    rows = Customer.recent.limit(limit).map do |customer|
      { customer_id: customer.id, projects: customer.projects.count, value: customer.lifetime_value.to_f }
    end

    render json: { simulated: "n_plus_one", customers: rows.size, data: rows }
  end

  # GET /debug/downstream?mode=slow|error -- pushes the failure into phr-api so
  # the two services can be told apart.
  def downstream
    case params[:mode]
    when "error"
      render json: api_client.simulate_error
    else
      render json: api_client.slow_query(seconds: params.fetch(:seconds, 3).to_f.clamp(0.1, 10.0))
    end
  end
end
