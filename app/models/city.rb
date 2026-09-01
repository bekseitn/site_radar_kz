class City < ApplicationRecord
  has_many :site_cities, dependent: :destroy
  has_many :sites, through: :site_cities

  validates :name, presence: true, uniqueness: true
end
