# Scores a lead and writes the result back to phr-api. This is the hop that
# produces web -> Redis -> worker -> HTTP -> api -> MySQL in a single logical
# unit of work.
class LeadScoringJob < ApplicationJob
  queue_as :lead_scoring

  SOURCE_WEIGHTS = {
    "referral"      => 35,
    "home_show"     => 25,
    "inbound_call"  => 20,
    "web_form"      => 15,
    "canvassing"    => 10,
    "direct_mail"   => 5
  }.freeze

  PRODUCT_WEIGHTS = {
    "roofing"           => 30,
    "siding"            => 25,
    "windows"           => 20,
    "doors"             => 12,
    "gutters"           => 8,
    "attic_insulation"  => 6
  }.freeze

  def perform(lead_id)
    client = PhrApiClient.new
    lead = client.lead(lead_id)

    score = compute_score(lead)
    status = next_status(score, lead["status"])

    client.update_lead(lead_id, score: score, status: status)
    Rails.logger.info("scored lead=#{lead_id} score=#{score} status=#{status}")

    ProjectProvisionJob.perform_later(lead_id) if status == "sold"
  rescue PhrApiClient::Error => e
    Rails.logger.error("lead scoring failed lead=#{lead_id} status=#{e.status.inspect} #{e.message}")
    raise
  end

  private

  def compute_score(lead)
    base = SOURCE_WEIGHTS.fetch(lead["source"], 10) +
           PRODUCT_WEIGHTS.fetch(lead["product_interest"], 10)

    value_bonus = [(lead["estimated_value"].to_f / 2_000).round, 30].min

    # Existing customers in the same market are a stronger signal, so this
    # touches the local MySQL schema as well as the API.
    neighbour_bonus = Customer.where(zip_code: lead["zip_code"]).limit(1).exists? ? 15 : 0

    (base + value_bonus + neighbour_bonus).clamp(0, 100)
  end

  def next_status(score, current_status)
    return current_status if %w[sold lost].include?(current_status)

    case score
    when 85..100 then "sold"
    when 65...85 then "appointment_set"
    when 40...65 then "qualified"
    else "contacted"
    end
  end
end
