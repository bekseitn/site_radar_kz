class AddVacancyTrackingBack < ActiveRecord::Migration[8.1]
  def change
    add_column :sites, :vacancy_url, :string
    add_column :site_technologies, :found_in_vacancy, :boolean, default: false, null: false
  end
end
