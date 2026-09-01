class CreateTechnologies < ActiveRecord::Migration[8.1]
  def change
    create_table :technologies do |t|
      t.string :name, null: false

      t.timestamps
    end

    add_index :technologies, :name, unique: true
  end
end
