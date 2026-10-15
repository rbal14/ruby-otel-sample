class CreateAppointments < ActiveRecord::Migration[7.1]
  def change
    create_table :appointments do |t|
      t.references :lead, null: false, foreign_key: true
      t.datetime :scheduled_at, null: false
      t.string   :rep_name,     null: false
      t.string   :branch,       null: false, default: "Philadelphia"
      t.string   :status,       null: false, default: "scheduled"
      t.string   :outcome
      t.decimal  :quoted_amount, precision: 12, scale: 2
      t.text     :notes

      t.timestamps
    end

    add_index :appointments, :scheduled_at
    add_index :appointments, %i[status scheduled_at]
  end
end
