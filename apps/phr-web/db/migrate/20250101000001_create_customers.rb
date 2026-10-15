class CreateCustomers < ActiveRecord::Migration[7.1]
  def change
    create_table :customers do |t|
      t.string :first_name, null: false
      t.string :last_name,  null: false
      t.string :email,      null: false
      t.string :phone
      t.string :street
      t.string :city,   null: false
      t.string :state,  null: false, limit: 2
      t.string :zip_code, null: false, limit: 10
      t.string :branch, null: false, default: "Philadelphia"
      t.bigint :source_lead_id
      t.timestamps
    end

    add_index :customers, :email, unique: true
    add_index :customers, :source_lead_id
    add_index :customers, %i[state city]
  end
end
