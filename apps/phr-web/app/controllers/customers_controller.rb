class CustomersController < ApplicationController
  def index
    page, per_page = page_params

    @customers = Customer.in_state(params[:state])
                         .recent
                         .limit(per_page)
                         .offset((page - 1) * per_page)
    @total = Customer.in_state(params[:state]).count
    @page = page
    @per_page = per_page
    @states = Customer.distinct.order(:state).pluck(:state)
  end

  def show
    @customer = Customer.includes(projects: :product).find(params[:id])
  end

  def new
    @customer = Customer.new
  end

  def create
    @customer = Customer.new(customer_params)

    if @customer.save
      redirect_to customer_path(@customer), notice: "Customer created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def customer_params
    params.require(:customer).permit(
      :first_name, :last_name, :email, :phone, :street, :city, :state, :zip_code, :branch
    )
  end
end
