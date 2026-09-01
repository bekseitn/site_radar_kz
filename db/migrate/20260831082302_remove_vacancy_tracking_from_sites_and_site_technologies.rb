class RemoveVacancyTrackingFromSitesAndSiteTechnologies < ActiveRecord::Migration[8.1]
  def change
    remove_column :sites, :vacancy_url, :string
    remove_column :site_technologies, :found_in_vacancy, :boolean, default: false, null: false
  end
end
