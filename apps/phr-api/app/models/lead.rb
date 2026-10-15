class Lead < ApplicationRecord
  SOURCES  = %w[web_form canvassing home_show referral inbound_call direct_mail].freeze
  STATUSES = %w[new contacted qualified appointment_set sold lost].freeze
  PRODUCTS = %w[windows siding doors roofing gutters attic_insulation].freeze

  has_many :appointments, dependent: :destroy

  validates :first_name, :last_name, :email, :zip_code, presence: true
  validates :source,           inclusion: { in: SOURCES }
  validates :status,           inclusion: { in: STATUSES }
  validates :product_interest, inclusion: { in: PRODUCTS }

  scope :by_status, ->(status) { where(status: status) if status.present? }
  scope :by_source, ->(source) { where(source: source) if source.present? }
  scope :recent,    -> { order(created_at: :desc) }

  def full_name
    "#{first_name} #{last_name}"
  end

  def as_json(options = {})
    super(options).merge("full_name" => full_name)
  end
end
