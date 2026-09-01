class SiteTechnology < ApplicationRecord
  belongs_to :site
  belongs_to :technology

  validates :site_id, uniqueness: { scope: :technology_id }
end
