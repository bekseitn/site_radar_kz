module SitesHelper
  # Simple Icons (simpleicons.org) brand SVGs via jsDelivr.
  # "twitter" maps to "x" since that's Simple Icons' current slug for it.
  SOCIAL_ICON_SLUGS = {
    "facebook" => "facebook",
    "instagram" => "instagram",
    "whatsapp" => "whatsapp",
    "telegram" => "telegram",
    "vk" => "vk",
    "linkedin" => "linkedin",
    "youtube" => "youtube",
    "twitter" => "x"
  }.freeze
  SOCIAL_ICON_CDN_BASE = "https://cdn.jsdelivr.net/npm/simple-icons@latest/icons/".freeze

  def social_link_label(platform) = platform.titleize

  def social_link_icon_url(platform)
    slug = SOCIAL_ICON_SLUGS.fetch(platform, platform)
    "#{SOCIAL_ICON_CDN_BASE}#{ERB::Util.url_encode(slug)}.svg"
  end

  # The name/description for the current locale: cached AI translation if
  # one exists, otherwise the original scraped text.
  def localized_site_name(site) = translated_field(site, "name") || site.name
  def localized_site_description(site) = translated_field(site, "description") || site.description

  # Whether this site is worth translating for the current locale.
  def needs_translation?(site, locale = I18n.locale)
    primary = site.primary_language&.name
    return false if primary.blank? || primary == locale.to_s

    site.translations&.dig(locale.to_s).blank?
  end

  private

  def translated_field(site, field)
    primary = site.primary_language&.name
    return nil if primary.blank? || primary == I18n.locale.to_s

    site.translations&.dig(I18n.locale.to_s, field).presence
  end
end
