class AddCategoryToSites < ActiveRecord::Migration[8.1]
  def change
    add_column :sites, :category, :string
  end
end
