class CreateProducts < ActiveRecord::Migration[7.1]
  def change
    create_table :products do |t|
      t.string  :sku,      null: false
      t.string  :name,     null: false
      t.string  :category, null: false
      t.decimal :unit_price, precision: 10, scale: 2, null: false
      t.string  :warranty_years
      t.timestamps
    end

    add_index :products, :sku, unique: true
    add_index :products, :category
  end
end
