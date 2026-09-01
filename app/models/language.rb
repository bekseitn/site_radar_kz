class Language < ApplicationRecord
  has_many :site_languages, dependent: :destroy
  has_many :sites, through: :site_languages

  validates :name, presence: true, uniqueness: true
end
