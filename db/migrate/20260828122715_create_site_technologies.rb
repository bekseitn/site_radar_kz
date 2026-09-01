class CreateSiteTechnologies < ActiveRecord::Migration[8.1]
  def change
    create_table :site_technologies do |t|
      t.references :site, null: false, foreign_key: true
      t.references :technology, null: false, foreign_key: true
      t.boolean :found_in_vacancy, null: false, default: false

      t.timestamps
    end

    add_index :site_technologies, %i[site_id technology_id], unique: true
  end
end
