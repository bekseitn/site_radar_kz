source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.1.3", ">= 8.1.3.1"
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft"
# Use sqlite3 as the database for Active Record
gem "sqlite3", ">= 2.1"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem "importmap-rails"
# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"
# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"
# Use Tailwind CSS [https://github.com/rails/tailwindcss-rails]
gem "tailwindcss-rails"
# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem "jbuilder"
# Locale data (date/number formats, pluralization rules) for Rails'
# ru/kk/en UI [https://github.com/svenfuchs/rails-i18n]
gem "rails-i18n"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Use the database-backed adapters for Rails.cache, Active Job, and Action Cable
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
gem "kamal", require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
gem "image_processing", "~> 1.2"

# HTTP client for the site scraper [https://github.com/lostisland/faraday]
gem "faraday"
# Follow redirects (http->https, bare domain->www, ...) instead of treating
# the redirect stub page's own tiny body as the site's real homepage
# [https://github.com/lostisland/faraday-follow_redirects]
gem "faraday-follow_redirects"
# HTML parsing for the scraper and the technology detector [https://nokogiri.org]
gem "nokogiri"
# Pagination for the site list [https://github.com/ddnexus/pagy]
gem "pagy"
# Progress bars for the long-running scraper/detector rake tasks [https://github.com/jfelchner/ruby-progressbar]
gem "ruby-progressbar"
# Pure-Ruby trigram language detection, for sites with no <html lang> to go on [https://github.com/peterc/whatlanguage]
gem "whatlanguage"
# Parses/validates hostnames against the real public suffix list, for the
# importers [https://github.com/weppos/publicsuffix-ruby]
gem "public_suffix"
# More forgiving URI parsing/joining than stdlib URI — used to resolve
# favicon/logo/og:image URLs found on real-world pages
# [https://github.com/sporkmonger/addressable]
gem "addressable"
# Parses/validates/formats phone numbers found on a site's homepage
# [https://github.com/daddyz/phonelib]
gem "phonelib"
# Checks that a favicon/logo/og:image URL is actually a real image (and
# how big) without downloading the whole file
# [https://github.com/sdsykes/fastimage]
gem "fastimage"
# Sortable columns on the site list [https://github.com/activerecord-hackery/ransack]
gem "ransack"
# SEO meta tags for SiteRadar's own catalog pages [https://github.com/kpumuk/meta-tags]
gem "meta-tags"
# Generates sitemap.xml for the public catalog [https://github.com/sitemap-generator/sitemap_generator]
gem "sitemap_generator"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Audits gems for known security defects (use config/bundler-audit.yml to ignore issues)
  gem "bundler-audit", require: false

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false

  # RSpec test framework [https://github.com/rspec/rspec-rails]
  gem "rspec-rails"

  # Fixtures replacement [https://github.com/thoughtbot/factory_bot_rails]
  gem "factory_bot_rails"
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"
end

group :development, :test do
  # Detects N+1 queries and unused eager loading [https://github.com/flyerhzm/bullet]
  gem "bullet"
end

group :test do
  # System tests [https://github.com/teamcapybara/capybara]
  gem "capybara"
  gem "selenium-webdriver"

  # Stub external HTTP calls made by the scraper/detector specs
  gem "webmock"
  gem "vcr"
end
