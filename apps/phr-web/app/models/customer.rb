class Customer < ApplicationRecord
  has_many :projects, dependent: :destroy

  validates :first_name, :last_name, :email, :city, :state, :zip_code, presence: true
  validates :email, uniqueness: true

  scope :in_state, ->(state) { where(state: state) if state.present? }
  scope :recent, -> { order(created_at: :desc) }

  def full_name
    "#{first_name} #{last_name}"
  end

  def lifetime_value
    projects.sum(:contract_amount)
  end
end
