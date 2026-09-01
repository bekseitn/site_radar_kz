# SiteRadar KZ

An open-source catalog of Kazakhstani (`.kz`) websites. It collects sites
from public lists, detects the technologies each one runs on
(Wappalyzer-style — CMS, JS frameworks, web servers, analytics, and more,
not just Ruby), and lets people browse and filter what it finds.

Sites are enriched with whatever their homepage gives up for free
(name, description, favicon, phone/email, social links, opening hours,
rating, geo coordinates, other language versions, ...) plus, optionally,
a local AI model for the parts that need judgment: a description when
there's none, a business category, the city a site is based in, whether
a domain looks parked, and finding a careers page among a site's links.

## Features

- **Filterable, sortable site catalog** — by city, category, technology
  (free-text search or a checkbox list), language, and hiring status.
  Turbo Frame filtering, no page reloads.
- **Site detail modal** — click a row for the full picture (contact
  info, social links, rating, opening hours, map link, ...) without
  leaving the list; also works as its own shareable page.
- **Technology detection** — a real Wappalyzer fingerprint database
  (vendored, see [Licensing](#licensing)), matched against a single GET
  request (headers, cookies, meta tags, script `src`, HTML — no
  headless browser).
- **Business info extraction** — schema.org/JSON-LD, Open Graph, and
  plain meta tags: description, category, city, phone, email, social
  links, logo, geo coordinates, rating, opening hours.
- **Vacancy page detection** — checks a handful of common careers-page
  paths (and, with AI on, the site's own nav links) for a mention of a
  detected technology.
- **Other-language-version detection** — `hreflang`, common locale
  paths/subdomains, and (with AI on) the site's own language switcher.
- **Local AI enrichment** (optional, via [Ollama](https://ollama.com), off
  by default) — description/category/city fallbacks, parked-domain
  flagging, smarter vacancy/language-link discovery, a shared category
  taxonomy built from the actual dataset, and on-demand translation of
  a site's scraped text into whichever locale a visitor is browsing in.
- **Full localization** — Russian (default), Kazakh, and English, with
  a language switcher.
- **Technology statistics page** — usage across the catalog, grouped by
  Wappalyzer's own technology categories (CMS, Analytics, Web servers, ...).

## Tech stack

Ruby 4.0, Rails 8.1, SQLite, Hotwire (Turbo + Stimulus), Tailwind CSS,
Solid Queue. Faraday + Nokogiri for scraping, Pagy for pagination,
Ransack for sortable columns, `meta-tags`/`sitemap_generator` for SEO.
RSpec + FactoryBot + Capybara + WebMock/VCR for tests.

## Getting started

```bash
bundle install
bin/rails db:setup
bin/rails tailwindcss:build
bin/rails server
```

Then open `http://localhost:3000`.

## Collecting and processing sites

```bash
# Import a plain list of hostnames (one per line)
bin/rails scrapers:import_domain_list[path/to/list.txt]

# Import from a Common Crawl CDX index
bin/rails scrapers:import_common_crawl[path/to/index]

# Detect technologies on every pending site
bin/rails scrapers:detect_technologies

# ...or just the first 100, for a quick test run
bin/rails scrapers:detect_technologies[100]
```

### With local AI

Install [Ollama](https://ollama.com), pull a model, and turn on the
detector's AI fallbacks with a second rake argument:

```bash
ollama pull qwen2.5:7b-instruct
ollama serve &

bin/rails scrapers:detect_technologies[,true]
```

If Ollama isn't reachable, the run stops with a clear error rather than
silently continuing without AI — safe to just rerun once it's back up,
since already-processed sites won't be touched again.
`bin/detect_with_ollama` runs the detector and, if Ollama dies partway
through, restarts it and picks the run back up automatically:

```bash
bin/detect_with_ollama         # every pending site
bin/detect_with_ollama 1000    # only the first 1000
```

AI is the slow part. On a big batch it's often faster to check every
site first without it, then go back and add AI enrichment only to the
sites that still need it:

```bash
bin/rails scrapers:detect_technologies   # fast pass, no AI
bin/rails scrapers:enrich_with_ai        # slow pass, AI only, skips ai_checked sites
```

Once enough sites have descriptions, build a shared category taxonomy
from the actual dataset and (re)classify every site into it:

```bash
bin/rails scrapers:build_category_taxonomy
bin/rails scrapers:categorize_sites
```

## Testing

```bash
bundle exec rspec
bin/rubocop
bin/brakeman
```

## Licensing

MIT, except `lib/wappalyzer_data/` — the vendored Wappalyzer technology
fingerprint dataset ([enthec/webappanalyzer](https://github.com/enthec/webappanalyzer)),
which is GPLv3. See [`LICENSE`](LICENSE) and
[`lib/wappalyzer_data/README.md`](lib/wappalyzer_data/README.md).
