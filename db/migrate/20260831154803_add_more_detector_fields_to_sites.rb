class AddMoreDetectorFieldsToSites < ActiveRecord::Migration[8.1]
  def change
    add_column :sites, :email, :string
    add_column :sites, :logo_url, :string
    add_column :sites, :latitude, :float
    add_column :sites, :longitude, :float
    add_column :sites, :rating, :float
    add_column :sites, :review_count, :integer
    add_column :sites, :opening_hours, :string
    add_column :sites, :noindex, :boolean, default: false, null: false
  end
end
