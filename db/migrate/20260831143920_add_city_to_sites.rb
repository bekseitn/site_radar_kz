class AddCityToSites < ActiveRecord::Migration[8.1]
  def change
    add_column :sites, :city, :string
  end
end
