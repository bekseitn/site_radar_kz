class AddMetadataToSites < ActiveRecord::Migration[8.1]
  def change
    add_column :sites, :description, :text
    add_column :sites, :image_url, :string
    add_column :sites, :favicon_url, :string
    add_column :sites, :language, :string
  end
end
