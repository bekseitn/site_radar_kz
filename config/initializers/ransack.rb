# The site list already uses params[:q] for the plain-text name/domain
# search box (Site.search_name_or_url) — Ransack's own default search_key
# is also :q, which would collide with it. Moving Ransack to :s (used only
# for the sortable column headers, via sort_link) keeps the two apart.
Ransack.configure do |config|
  config.search_key = :s
end
