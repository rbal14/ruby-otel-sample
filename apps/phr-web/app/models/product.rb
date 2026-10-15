class Product < ApplicationRecord
  CATEGORIES = %w[windows siding doors roofing gutters attic_insulation].freeze

  has_many :projects, dependent: :restrict_with_error

  validates :sku, :name, :category, :unit_price, presence: true
  validates :category, inclusion: { in: CATEGORIES }
end
