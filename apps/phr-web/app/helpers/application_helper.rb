module ApplicationHelper
  STATUS_COLORS = {
    "new" => "#6b7280", "contacted" => "#0ea5e9", "qualified" => "#6366f1",
    "appointment_set" => "#8b5cf6", "sold" => "#16a34a", "lost" => "#dc2626",
    "pending_permit" => "#6b7280", "permitted" => "#0ea5e9", "scheduled" => "#6366f1",
    "in_progress" => "#f59e0b", "punch_list" => "#8b5cf6", "completed" => "#16a34a",
    "cancelled" => "#dc2626", "confirmed" => "#0ea5e9", "no_show" => "#dc2626"
  }.freeze

  def status_badge(status)
    return "" if status.blank?

    color = STATUS_COLORS.fetch(status.to_s, "#6b7280")
    tag.span(status.to_s.tr("_", " "),
             class: "badge",
             style: "background:#{color}1a;color:#{color};border:1px solid #{color}40")
  end

  def money(amount)
    number_to_currency(amount.to_f, precision: 0)
  end

  def humanize_key(key)
    key.to_s.tr("_", " ").titleize
  end
end
