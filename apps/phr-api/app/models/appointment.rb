class Appointment < ApplicationRecord
  STATUSES = %w[scheduled confirmed completed cancelled no_show].freeze
  OUTCOMES = %w[sold not_sold follow_up not_qualified].freeze

  belongs_to :lead

  validates :scheduled_at, :rep_name, presence: true
  validates :status,  inclusion: { in: STATUSES }
  validates :outcome, inclusion: { in: OUTCOMES }, allow_nil: true

  scope :upcoming, -> { where("scheduled_at >= ?", Time.current).order(:scheduled_at) }
  scope :by_status, ->(status) { where(status: status) if status.present? }
end
