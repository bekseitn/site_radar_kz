# Generates public/sitemaps/sitemap.xml.gz — run "bin/rails sitemap:refresh"
# (dev server host defaults below; set SitemapGenerator::Sitemap.default_host
# via SITEMAP_HOST in production, e.g. from a deploy task).
require "rubygems"
require "sitemap_generator"

SitemapGenerator::Sitemap.default_host = ENV.fetch("SITEMAP_HOST", "https://siteradar.example")
# create's own include_root: true default already adds "/" — with its
# own (different) defaults, so it'd show up twice unless disabled here.
SitemapGenerator::Sitemap.include_root = false

SitemapGenerator::Sitemap.create do
  # The catalog is one big filterable/paginated index (resources :sites,
  # only: :index — no per-site show page exists), so there's exactly one
  # real URL worth listing: the root itself. Country/category/etc. filter
  # combinations aren't included — there are thousands of them, and
  # they're not distinct crawlable content so much as views over the same
  # data, which would just dilute the sitemap instead of helping it.
  add root_path, changefreq: "daily", priority: 1.0
end
