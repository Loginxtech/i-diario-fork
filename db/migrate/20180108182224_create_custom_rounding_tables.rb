class CreateCustomRoundingTables < ActiveRecord::Migration
  def change
    create_table :custom_rounding_tables do |t|
      t.integer :year
      t.string :name

      t.timestamps null: false
    end
  end
end
