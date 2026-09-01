# is_primary marks the site's main declared language, as opposed to the
# other languages it merely offers (hreflang alternates, language switcher).
class SiteLanguage < ApplicationRecord
  belongs_to :site
  belongs_to :language

  validates :site_id, uniqueness: { scope: :language_id }
end
