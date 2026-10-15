class Project < ApplicationRecord
  STATUSES = %w[pending_permit permitted scheduled in_progress punch_list completed cancelled].freeze

  belongs_to :customer
  belongs_to :product

  validates :name, :contract_amount, presence: true
  validates :status, inclusion: { in: STATUSES }

  scope :by_status, ->(status) { where(status: status) if status.present? }
  scope :active, -> { where.not(status: %w[completed cancelled]) }
  scope :recent, -> { order(created_at: :desc) }

  def revenue_recognized?
    status == "completed"
  end
end
