class SitesController < ApplicationController
  include Pagy::Method
  include SitesHelper # for localized_site_name/description and needs_translation?

  def index
    # Ransack drives only the sortable column headers (param key :s).
    # Named @sort_search, not @q, since params[:q] is the text search box.
    @sort_search = Site.checked.ransack(params[:s])
    # site_languages is eager-loaded too since localized_site_name/description read it per row.
    scope = @sort_search.result(distinct: true).includes(:technologies, :categories, site_languages: :language)
    scope = scope.order(:url) if params[:s].blank?

    scope = scope.with_city(params[:city]) if params[:city].present?
    scope = scope.with_category(params[:category]) if params[:category].present?
    scope = scope.with_language(params[:language]) if params[:language].present?
    scope = scope.search_name_or_url(params[:q]) if params[:q].present?
    scope = scope.with_technology_like(params[:technology]) if params[:technology].present?
    scope = scope.with_technologies(params[:technologies]) if params[:technologies].present?
    scope = scope.where.not(vacancy_url: nil) if params[:vacancy] == "hiring"

    @pagy, @sites = pagy(:offset, scope, limit: 200, max_limit: 400)
    @cities = City.order(:name).pluck(:name)
    @categories = Category.order(:name).pluck(:name)
    @languages = Language.order(:name).pluck(:name)
    @technologies = Technology.order(:name).pluck(:name)

    tags = index_meta_tags
    set_meta_tags(**tags) if tags.present?
  end

  # Rendered both as the modal's content (row click) and, on a direct
  # visit, as its own full shareable page.
  def show
    @site = Site.find(params[:id])

    # Translates in the background so this request doesn't block on it;
    # the original text shows now, the translation next time it's viewed.
    TranslateSiteJob.perform_later(@site.id, I18n.locale.to_s) if needs_translation?(@site)

    set_meta_tags(title: localized_site_name(@site).presence || @site.url, description: localized_site_description(@site))
  end

  private

  # Reflects active filters into the page title/description.
  def index_meta_tags
    parts = [ params[:category], params[:technology], params[:city], params[:language] ].select(&:present?)
    return {} if parts.empty?

    label = parts.join(" · ")
    { title: label, description: t("sites.meta.filtered_description", label: label) }
  end
end
