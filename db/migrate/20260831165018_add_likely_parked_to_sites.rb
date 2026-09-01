class AddLikelyParkedToSites < ActiveRecord::Migration[8.1]
  def change
    add_column :sites, :likely_parked, :boolean
  end
end
