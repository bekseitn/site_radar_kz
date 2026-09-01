class CreateSites < ActiveRecord::Migration[8.1]
  def change
    create_table :sites do |t|
      t.string :name
      t.string :url, null: false
      t.string :country
      t.string :vacancy_url
      t.string :source
      t.integer :status, null: false, default: 0
      t.datetime :last_checked_at

      t.timestamps
    end

    add_index :sites, :url, unique: true
    add_index :sites, :country
    add_index :sites, :status
  end
end
