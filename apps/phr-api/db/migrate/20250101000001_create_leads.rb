class CreateLeads < ActiveRecord::Migration[7.1]
  def change
    create_table :leads do |t|
      t.string  :first_name,       null: false
      t.string  :last_name,        null: false
      t.string  :email,            null: false
      t.string  :phone
      t.string  :zip_code,         null: false, limit: 10
      t.string  :source,           null: false, default: "web_form"
      t.string  :product_interest, null: false, default: "windows"
      t.string  :status,           null: false, default: "new"
      t.integer :score,            null: false, default: 0
      t.decimal :estimated_value,  precision: 12, scale: 2
      t.text    :notes

      t.timestamps
    end

    add_index :leads, :email
    add_index :leads, :status
    add_index :leads, %i[status created_at]
    # zip_code is deliberately left unindexed -- /simulate/table_scan filters on
    # it so there is an easy, explainable full scan to look at in the POC.
  end
end
