class Site < ApplicationRecord
  enum :status, { pending: 0, checked: 1, unreachable: 2 }, default: :pending

  has_many :site_technologies, dependent: :destroy
  has_many :technologies, through: :site_technologies

  has_many :site_categories, dependent: :destroy
  has_many :categories, through: :site_categories

  has_many :site_languages, dependent: :destroy
  has_many :languages, through: :site_languages

  has_many :site_cities, dependent: :destroy
  has_many :cities, through: :site_cities

  before_validation :normalize_url

  # http(s)-only, so a link_to using these can never render a javascript:
  # or data: URL from scraped content.
  URL_FORMAT = %r{\Ahttps?://\S+\z}i

  validates :url, presence: true, uniqueness: true, format: URL_FORMAT
  validates :vacancy_url, format: URL_FORMAT, allow_blank: true

  # Allowlist for Ransack — only columns the site list actually sorts by.
  def self.ransackable_attributes(_auth_object = nil)
    %w[url name country rating review_count last_checked_at]
  end

  def self.ransackable_associations(_auth_object = nil) = []

  # Class method so importers can normalize a url before checking Site.exists?.
  def self.normalize_url(raw)
    return raw if raw.blank?

    parsed = Addressable::URI.parse(raw.strip)
    parsed.path = "/" if parsed.path.blank?
    parsed.to_s
  rescue Addressable::URI::InvalidURIError
    raw
  end

  # Sites detected with the local-AI fallbacks on (see TechnologyDetector).
  scope :ai_checked, -> { where(ai_checked: true) }

  scope :search_name_or_url, ->(term) {
    pattern = "%#{sanitize_sql_like(term)}%"
    where("sites.name LIKE ? OR sites.url LIKE ?", pattern, pattern)
  }

  # Subquery instead of a direct join, so it doesn't restrict the controller's
  # eager-loaded :technologies to just the matching one.
  scope :with_technology_like, ->(term) {
    pattern = "%#{sanitize_sql_like(term)}%"
    matching_site_ids = SiteTechnology.joins(:technology).where("technologies.name LIKE ?", pattern).select(:site_id)
    where(id: matching_site_ids)
  }

  # Matches a site with any of the given technology names.
  scope :with_technologies, ->(names) {
    matching_site_ids = SiteTechnology.joins(:technology).where(technologies: { name: names }).select(:site_id)
    where(id: matching_site_ids)
  }

  # Same subquery-not-direct-join reasoning as with_technology_like above.
  scope :with_category, ->(name) {
    matching_site_ids = SiteCategory.joins(:category).where(categories: { name: name }).select(:site_id)
    where(id: matching_site_ids)
  }

  # Same subquery-not-direct-join reasoning as with_category above.
  scope :with_city, ->(name) {
    matching_site_ids = SiteCity.joins(:city).where(cities: { name: name }).select(:site_id)
    where(id: matching_site_ids)
  }

  # Matches on any language the site has, not just its primary one.
  scope :with_language, ->(name) {
    matching_site_ids = SiteLanguage.joins(:language).where(languages: { name: name }).select(:site_id)
    where(id: matching_site_ids)
  }

  # The language flagged is_primary, or nil if not yet detected.
  def primary_language
    site_languages.find { |site_language| site_language.is_primary }&.language
  end

  private

  # Appends "/" only for an empty path, so "https://zero.kz" and
  # "https://zero.kz/" don't count as different urls.
  def normalize_url
    self.url = self.class.normalize_url(url) if url.present?
  end
end
