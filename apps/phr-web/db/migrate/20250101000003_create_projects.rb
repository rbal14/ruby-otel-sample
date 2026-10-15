class CreateProjects < ActiveRecord::Migration[7.1]
  def change
    create_table :projects do |t|
      t.references :customer, null: false, foreign_key: true
      t.references :product,  null: false, foreign_key: true
      t.string  :name,   null: false
      t.string  :status, null: false, default: "pending_permit"
      t.decimal :contract_amount, precision: 12, scale: 2, null: false
      t.date    :start_date
      t.date    :completion_date
      t.string  :crew_name
      t.string  :branch, null: false, default: "Philadelphia"
      t.integer :quantity, null: false, default: 1
      t.text    :scope_notes
      t.timestamps
    end

    add_index :projects, :status
    add_index :projects, %i[status start_date]
  end
end
