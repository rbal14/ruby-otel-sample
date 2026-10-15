# Turns a sold lead into a customer + project in the phr_web schema.
class ProjectProvisionJob < ApplicationJob
  queue_as :provisioning

  def perform(lead_id)
    lead = PhrApiClient.new.lead(lead_id)

    customer = Customer.find_or_initialize_by(email: lead["email"])
    customer.assign_attributes(
      first_name: lead["first_name"],
      last_name: lead["last_name"],
      phone: lead["phone"],
      city: customer.city.presence || "Philadelphia",
      state: customer.state.presence || "PA",
      zip_code: lead["zip_code"],
      source_lead_id: lead["id"]
    )
    customer.save!

    product = Product.find_by(category: lead["product_interest"]) || Product.first
    return Rails.logger.warn("no products seeded, skipping provision for lead=#{lead_id}") if product.nil?

    quantity = [(lead["estimated_value"].to_f / product.unit_price.to_f).ceil, 1].max

    project = Project.find_or_initialize_by(customer: customer, product: product, status: "pending_permit")
    project.assign_attributes(
      name: "#{product.category.tr('_', ' ').titleize} - #{customer.full_name}",
      contract_amount: lead["estimated_value"].presence || (product.unit_price * quantity),
      quantity: quantity,
      branch: customer.branch,
      start_date: Date.current + 21.days,
      scope_notes: lead["notes"]
    )
    project.save!

    Rails.logger.info("provisioned project=#{project.id} customer=#{customer.id} from lead=#{lead_id}")
  end
end
