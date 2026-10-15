# Leads live in phr-api, not in this app's database. Every action here is an
# outbound HTTP call.
class LeadsController < ApplicationController
  def index
    page, per_page = page_params

    payload = api_client.leads(
      status: params[:status].presence,
      source: params[:source].presence,
      page: page,
      per_page: per_page
    )

    @leads    = payload.fetch("leads", [])
    @total    = payload["total"].to_i
    @page     = page
    @per_page = per_page
  end

  def show
    @lead = api_client.lead(params[:id])
  end
end
