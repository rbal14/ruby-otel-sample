# Idempotent seed data -- safe to re-run on every deploy. Leads are keyed by
# email so re-running updates rather than duplicating.

FIRST_NAMES = %w[
  Alex Jordan Casey Morgan Riley Taylor Devon Shannon Hayley Marcus
  Priya Elena Tomas Nia Kwame Rosa Dmitri Aisha Colin Bethany
].freeze

LAST_NAMES = %w[
  Reyes Okafor Lindqvist Whitfield Nakamura Duarte Kowalski Mbeki
  Fitzgerald Ivanova Haddad Sorensen Aguilar Petrov Calloway Osei
].freeze

# Power Home Remodeling's actual footprint skews to the Northeast / Mid-Atlantic.
BRANCHES = [
  ["Philadelphia", "19103"],
  ["Chester",      "19013"],
  ["Baltimore",    "21201"],
  ["Northern Virginia", "22030"],
  ["Charlotte",    "28202"],
  ["Nashville",    "37203"],
  ["Dallas",       "75201"],
  ["Denver",       "80202"],
  ["Long Island",  "11530"],
  ["Boston",       "02108"]
].freeze

REPS = [
  "M. Delacroix", "S. Ravensworth", "T. Abernathy", "K. Villanueva",
  "J. Thorsden", "L. Ferreira", "B. Achterberg"
].freeze

NOTE_SNIPPETS = [
  "Homeowner asked about roof replacement financing options.",
  "Wants siding quote before the winter season.",
  "Interested in triple-pane window upgrade for the second floor.",
  "Referred by a neighbor who had gutters installed last spring.",
  "Attic insulation follow-up, needs an energy audit first.",
  "Door replacement, front entry only.",
  "Roof and gutters bundled estimate requested."
].freeze

SEED_LEAD_COUNT = Integer(ENV.fetch("SEED_LEAD_COUNT", 400))

random = Random.new(20250101)

puts "seeding #{SEED_LEAD_COUNT} leads into #{ActiveRecord::Base.connection.current_database} ..."

SEED_LEAD_COUNT.times do |index|
  branch, zip = BRANCHES[index % BRANCHES.size]
  first = FIRST_NAMES[random.rand(FIRST_NAMES.size)]
  last  = LAST_NAMES[random.rand(LAST_NAMES.size)]
  status = Lead::STATUSES[random.rand(Lead::STATUSES.size)]

  lead = Lead.find_or_initialize_by(email: "lead#{index + 1}@example-phr.test")
  lead.assign_attributes(
    first_name: first,
    last_name: last,
    phone: format("215-555-%04d", index % 10_000),
    zip_code: zip,
    source: Lead::SOURCES[random.rand(Lead::SOURCES.size)],
    product_interest: Lead::PRODUCTS[random.rand(Lead::PRODUCTS.size)],
    status: status,
    score: random.rand(0..100),
    estimated_value: (random.rand(4_000..48_000)).to_d,
    notes: "#{NOTE_SNIPPETS[random.rand(NOTE_SNIPPETS.size)]} Branch: #{branch}."
  )
  lead.save!

  # Roughly half the leads that got past "contacted" have an appointment.
  next unless %w[appointment_set sold lost].include?(status)
  next if lead.appointments.exists?

  Appointment.create!(
    lead: lead,
    scheduled_at: Time.current + random.rand(-30..21).days + random.rand(9..18).hours,
    rep_name: REPS[random.rand(REPS.size)],
    branch: branch,
    status: %w[scheduled confirmed completed cancelled no_show][random.rand(5)],
    outcome: (status == "sold" ? "sold" : %w[not_sold follow_up not_qualified][random.rand(3)]),
    quoted_amount: (random.rand(5_000..60_000)).to_d,
    notes: "Appointment for #{lead.product_interest} at #{branch}."
  )
end

puts "leads: #{Lead.count}, appointments: #{Appointment.count}"
