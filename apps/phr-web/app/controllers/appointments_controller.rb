class AppointmentsController < ApplicationController
  def index
    page, per_page = page_params

    payload = api_client.appointments(
      status: params[:status].presence,
      page: page,
      per_page: per_page
    )

    @appointments = payload.fetch("appointments", [])
    @total    = payload["total"].to_i
    @page     = page
    @per_page = per_page
  end
end
