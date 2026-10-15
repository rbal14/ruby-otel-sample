class DashboardController < ApplicationController
  def index
    # Local schema (phr_web)
    @customer_count = Customer.count
    @project_count  = Project.count
    @active_projects = Project.active.count
    @contract_value = Project.active.sum(:contract_amount)
    @projects_by_status = Project.group(:status).count
    @recent_projects = Project.includes(:customer, :product).recent.limit(8)
    @top_branches = Project.group(:branch)
                           .order(Arel.sql("SUM(contract_amount) DESC"))
                           .limit(5)
                           .sum(:contract_amount)

    # Remote service (phr-api -> phr_api schema). Rendered as "unavailable"
    # rather than failing the page, so the dashboard degrades gracefully.
    @api_stats = fetch_api_stats
  end

  private

  def fetch_api_stats
    api_client.stats
  rescue PhrApiClient::Error => e
    Rails.logger.warn("dashboard could not load api stats: #{e.message}")
    nil
  end
end
