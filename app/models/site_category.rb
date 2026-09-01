class SiteCategory < ApplicationRecord
  belongs_to :site
  belongs_to :category

  validates :site_id, uniqueness: { scope: :category_id }
end
