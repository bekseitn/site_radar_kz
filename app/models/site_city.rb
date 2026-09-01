class SiteCity < ApplicationRecord
  belongs_to :site
  belongs_to :city

  validates :site_id, uniqueness: { scope: :city_id }
end
