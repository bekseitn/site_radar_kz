# SiteRadar KZ — project plan

> Working title, easy to change if needed — mentions of the name in code
> are minimal (module namespace, layout heading).

## 1. Description
SiteRadar KZ is an open-source aggregator app that collects sites from
public lists, automatically detects the technologies each site is built
on (Wappalyzer-style — CMS, JS frameworks, web servers, analytics, etc.,
not just Ruby/Rails), and lets users browse and filter the sites it
finds by country and technology.

## 2. Tech stack
- Ruby 4.0
- Rails 8.1
- SQLite (Rails 8's built-in adapters; Solid Queue instead of Redis/Sidekiq)
- Frontend: Hotwire (Turbo + Stimulus), no SPA framework
- Styling: Tailwind CSS
- HTTP client for scraping: Faraday, plus Nokogiri for HTML parsing
- Background jobs: Solid Queue
- Tests: RSpec + FactoryBot + Capybara (system tests) + WebMock/VCR
  (to stub HTTP requests in scraper/detector tests)
- Deploy: not a priority yet, local development only

## 3. Data model

```
Site
  name          :string    — site name/title
  url           :string    — the site's own URL (unique, required)
  country       :string    — country (normalized code, e.g. ISO 3166-1 alpha-2)
  source        :string    — where the site came from (e.g. "common_crawl", "domain_list")
  status        :integer   — enum: pending, checked, unreachable
  last_checked_at :datetime

  has_many :site_technologies
  has_many :technologies, through: :site_technologies

Technology
  name          :string    — e.g. "Ruby on Rails", "WordPress", "Nginx"
  category      :string    — Wappalyzer's own category
                              (e.g. "CMS", "Web frameworks", "Analytics")

SiteTechnology (join table)
  belongs_to :site
  belongs_to :technology
```

Why:
- `url` is required and unique, to avoid duplicates on a re-scrape
  (importers upsert by `url`).
- Technologies live in their own table with a many-to-many relationship —
  a site can use several technologies at once.
- `status` and `last_checked_at` track which sites the detector has
  already checked, so a rerun only touches new/unchecked ones.

## 4. Features

### Feature 1 — Filterable site list (the public part)
The product's main value for a user.
- A home page listing every site (name, url, country, technologies)
- A country filter
- Pagination
- The list updates via Turbo Frame on filter change, no page reload
- An empty state when a filter matches nothing

### Feature 2 — Importing sites from external lists
- Service objects under `app/services/importers/` (`Importers::CommonCrawlImporter`,
  `Importers::DomainListImporter`), each reading its own source format
  (a Common Crawl JSON Lines index / a plain one-domain-per-line list)
  and extracting a list of sites
- Sites are upserted by `url` (no duplicates on a rerun)
- Run manually via a rake task (`rails scrapers:import_common_crawl[path]`,
  `rails scrapers:import_domain_list[path]`) — not through the public
  web UI, so outsiders can't trigger an import
- Built for more than one source: scrapers (as opposed to file importers)
  share a `Scrapers::BaseScraper` interface — polite HTTP (a delay
  between requests, its own User-Agent, retry with backoff, a summary
  log) — so a new source can be added without touching existing ones

### Feature 3 — Site technology detection
- `TechnologyDetector` walks every `pending` site, fetches its homepage,
  and runs it through `Wappalyzer::Analyzer`
- `Wappalyzer::Analyzer` interprets real Wappalyzer fingerprints
  (vendored under `lib/wappalyzer_data/`, the `enthec/webappanalyzer`
  dataset):
  - response headers, cookies (exact name match, not substring), meta
    tags, `<script src>`, HTML — everything checkable from a single GET
    request (no real browser — `dom`/`js`/`css` signatures aren't
    supported)
  - a technology is detected on any single matching signature
    (Wappalyzer's own algorithm), `implies` (e.g. Rails implies Ruby)
    and `excludes` are resolved too
- Every technology found (with its category) is saved to `technologies`
  through `site_technologies`
- Run manually via `rails scrapers:detect_technologies`
- A checked site gets `status: checked` (or `unreachable` if it
  couldn't be reached), so it isn't checked again next run

## 5. Out of scope (not doing this now)
- User registration/authentication
- Adding sites manually through a form (only via the scraper/importers)
- Scheduled/cron re-scraping — manual runs only
- An API for external clients
- Notifications, comments, any social features

## 6. Feature readiness checklist
- RSpec tests exist (models + at least one system test per flow)
- Scraper/detector tests use WebMock/VCR (no real HTTP requests in tests)
- `bundle exec rspec` passes
- Manually verified in the browser (dev server)
- No N+1 queries on list pages (check with the bullet gem)
- Rerunning the scraper/detector doesn't create duplicates or fail on
  already-processed records

## 7. Code conventions
- Skinny controllers, business logic lives in service objects (`app/services`)
- Each scraper/detector is its own class with a single public entry
  point (`.call`), for easy testing and calling from a rake task
- Variable and commit names are in English
- Each feature gets its own branch and PR
- License: MIT (the standard choice for Ruby open source), except
  `lib/wappalyzer_data/` — Wappalyzer's technology fingerprint dataset
  (enthec/webappanalyzer), which is GPLv3 — see `lib/wappalyzer_data/README.md`
