class AddContactInfoToSites < ActiveRecord::Migration[8.1]
  def change
    add_column :sites, :phone, :string
    add_column :sites, :social_links, :json
  end
end
