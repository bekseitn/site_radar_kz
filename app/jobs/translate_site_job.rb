# Runs Ai::Translator for one site/locale pair and caches the result on
# Site#translations. Runs in the background since local model inference
# can take several seconds.
class TranslateSiteJob < ApplicationJob
  queue_as :default

  def perform(site_id, locale)
    site = Site.find_by(id: site_id)
    return if site.nil?
    return if (site.translations || {})[locale].present? # already translated

    translation = Ai::Translator.call(name: site.name, description: site.description, target_locale: locale)
    return if translation.blank?

    site.update!(translations: (site.translations || {}).merge(locale => translation))
  end
end
