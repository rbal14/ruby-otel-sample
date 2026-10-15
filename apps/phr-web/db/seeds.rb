# Idempotent seed data -- safe to re-run on every deploy.

PRODUCT_CATALOG = [
  { sku: "WIN-DH-TRI",  name: "Triple-Pane Double Hung Window", category: "windows",          unit_price: 1_150.00, warranty_years: "lifetime" },
  { sku: "WIN-CS-TRI",  name: "Triple-Pane Casement Window",    category: "windows",          unit_price: 1_320.00, warranty_years: "lifetime" },
  { sku: "SID-VNL-PRM", name: "Insulated Vinyl Siding (sq)",    category: "siding",           unit_price: 780.00,   warranty_years: "lifetime" },
  { sku: "DOR-ENT-FBG", name: "Fiberglass Entry Door",          category: "doors",            unit_price: 2_450.00, warranty_years: "25" },
  { sku: "ROF-ARCH-30", name: "Architectural Shingle Roof (sq)", category: "roofing",         unit_price: 640.00,   warranty_years: "50" },
  { sku: "GUT-SEAM-6",  name: "Seamless 6\" Gutter (lf)",       category: "gutters",          unit_price: 18.50,    warranty_years: "20" },
  { sku: "ATT-BLOWN-R49", name: "Blown-In Attic Insulation R-49", category: "attic_insulation", unit_price: 2.85,   warranty_years: "lifetime" }
].freeze

BRANCHES = [
  ["Philadelphia", "PA", "19103"],
  ["Chester", "PA", "19013"],
  ["Baltimore", "MD", "21201"],
  ["Fairfax", "VA", "22030"],
  ["Charlotte", "NC", "28202"],
  ["Nashville", "TN", "37203"],
  ["Dallas", "TX", "75201"],
  ["Denver", "CO", "80202"],
  ["Garden City", "NY", "11530"],
  ["Boston", "MA", "02108"]
].freeze

FIRST_NAMES = %w[
  Alex Jordan Casey Morgan Riley Taylor Devon Shannon Hayley Marcus
  Priya Elena Tomas Nia Kwame Rosa Dmitri Aisha Colin Bethany
].freeze

LAST_NAMES = %w[
  Reyes Okafor Lindqvist Whitfield Nakamura Duarte Kowalski Mbeki
  Fitzgerald Ivanova Haddad Sorensen Aguilar Petrov Calloway Osei
].freeze

CREWS = ["Crew A - Tomlinson", "Crew B - Vasquez", "Crew C - Okonkwo", "Crew D - Brennan", "Crew E - Sato"].freeze

STREETS = ["Chestnut St", "Walnut Ave", "Ridge Rd", "Lancaster Pike", "Mill Creek Ln", "Sycamore Dr", "Ivy Bridge Way"].freeze

SEED_CUSTOMER_COUNT = Integer(ENV.fetch("SEED_CUSTOMER_COUNT", "150"))

puts "seeding into #{ActiveRecord::Base.connection.current_database} ..."

PRODUCT_CATALOG.each do |attributes|
  product = Product.find_or_initialize_by(sku: attributes[:sku])
  product.assign_attributes(attributes)
  product.save!
end
puts "products: #{Product.count}"

products = Product.order(:id).to_a
random = Random.new(20250101)

SEED_CUSTOMER_COUNT.times do |index|
  city, state, zip = BRANCHES[index % BRANCHES.size]

  customer = Customer.find_or_initialize_by(email: "customer#{index + 1}@example-phr.test")
  customer.assign_attributes(
    first_name: FIRST_NAMES[random.rand(FIRST_NAMES.size)],
    last_name: LAST_NAMES[random.rand(LAST_NAMES.size)],
    phone: format("215-555-%04d", index % 10_000),
    street: "#{random.rand(100..9999)} #{STREETS[random.rand(STREETS.size)]}",
    city: city,
    state: state,
    zip_code: zip,
    branch: city
  )
  customer.save!

  # One to three projects each, keyed by product so re-running is a no-op.
  project_count = random.rand(1..3)
  products.sample(project_count, random: random).each do |product|
    quantity = random.rand(1..24)
    status = Project::STATUSES[random.rand(Project::STATUSES.size)]
    start_date = Date.current + random.rand(-120..45).days

    project = Project.find_or_initialize_by(customer: customer, product: product)
    project.assign_attributes(
      name: "#{product.category.tr('_', ' ').titleize} - #{customer.last_name} (#{city})",
      status: status,
      contract_amount: (product.unit_price * quantity).round(2),
      quantity: quantity,
      branch: city,
      crew_name: CREWS[random.rand(CREWS.size)],
      start_date: start_date,
      completion_date: (status == "completed" ? start_date + random.rand(3..21).days : nil),
      scope_notes: "#{quantity}x #{product.name} at #{customer.street}, #{city} #{state}."
    )
    project.save!
  end
end

puts "customers: #{Customer.count}, projects: #{Project.count}"
