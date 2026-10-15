class ProjectsController < ApplicationController
  def index
    page, per_page = page_params

    scope = Project.by_status(params[:status]).includes(:customer, :product)

    @projects = scope.recent.limit(per_page).offset((page - 1) * per_page)
    @total = Project.by_status(params[:status]).count
    @page = page
    @per_page = per_page
    @statuses = Project::STATUSES
  end

  def show
    @project = Project.includes(:customer, :product).find(params[:id])
  end
end
