class Technology < ApplicationRecord
  # Link to Wappalyzer's icon set on jsDelivr instead of vendoring it.
  ICON_CDN_BASE = "https://cdn.jsdelivr.net/gh/enthec/webappanalyzer@main/src/images/icons/".freeze

  has_many :site_technologies, dependent: :destroy
  has_many :sites, through: :site_technologies

  validates :name, presence: true, uniqueness: true

  def icon_url
    return if icon.blank?

    "#{ICON_CDN_BASE}#{ERB::Util.url_encode(icon)}"
  end
end
