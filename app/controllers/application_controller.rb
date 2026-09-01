class ApplicationController < ActionController::Base
  # Only allow modern browsers.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :set_locale
  before_action :set_default_meta_tags

  private

  # Falls back to the default locale (Russian) for anything not "kk" or "en".
  def set_locale
    I18n.locale = params[:locale].presence_in(I18n.available_locales.map(&:to_s)) || I18n.default_locale
  end

  # Carries the current locale forward on every url_for/*_path/*_url call.
  def default_url_options
    { locale: I18n.locale == I18n.default_locale ? nil : I18n.locale }
  end

  # Actions can override/add to these with their own set_meta_tags call.
  def set_default_meta_tags
    set_meta_tags(
      title: t("layout.default_title"),
      description: t("layout.default_description"),
      og: { type: "website" }
    )
  end
end
