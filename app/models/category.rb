class Category < ApplicationRecord
  has_many :site_categories, dependent: :destroy
  has_many :sites, through: :site_categories

  validates :name, presence: true, uniqueness: true
end
