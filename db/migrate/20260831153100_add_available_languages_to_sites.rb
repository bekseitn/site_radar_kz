class AddAvailableLanguagesToSites < ActiveRecord::Migration[8.1]
  def change
    add_column :sites, :available_languages, :json
  end
end
