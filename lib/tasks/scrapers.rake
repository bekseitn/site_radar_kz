require "ruby-progressbar"

# Builds an on_progress callback backed by a visible progress bar. Pass
# just a count if the total isn't known upfront, or pass total once it is.
def progress_bar(title)
  bar = ProgressBar.create(title: title, total: nil, format: "%t: |%B| %c/%C %p%% ETA: %e")
  ->(done, total = nil) do
    bar.total = total if total
    bar.progress = done
  end
end

namespace :scrapers do
  desc "Detect technology on sites with status 'pending' (rails scrapers:detect_technologies[100] to only check 100 this run, rails scrapers:detect_technologies[,true] to also use a local Ollama model — see Ai::Client — for description/category/vacancy-link fallbacks)"
  task :detect_technologies, [ :limit, :ai ] => :environment do |_, args|
    limit = args[:limit].presence&.to_i
    ai_enabled = ActiveModel::Type::Boolean.new.cast(args[:ai])
    TechnologyDetector.call(limit: limit, ai_enabled: ai_enabled, on_progress: progress_bar("detect"))
  end

  desc "Re-run already-checked sites through the AI fallbacks only (rails scrapers:enrich_with_ai[100] to only check 100 this run) — for after a plain scrapers:detect_technologies run, to add AI enrichment without re-checking everything"
  task :enrich_with_ai, [ :limit ] => :environment do |_, args|
    limit = args[:limit].presence&.to_i
    scope = Site.checked.where(ai_checked: false)
    TechnologyDetector.call(limit: limit, ai_enabled: true, scope: scope, on_progress: progress_bar("enrich"))
  end

  desc "Phase 1: sample site descriptions and build a shared category taxonomy (Category rows) with a local Ollama model"
  task build_category_taxonomy: :environment do
    categories = Ai::CategoryTaxonomyBuilder.call(on_progress: progress_bar("taxonomy"))
    puts "#{categories.size} categories:"
    puts categories.join(", ")
  end

  desc "Phase 2: classify every site with a description into the Category taxonomy (run scrapers:build_category_taxonomy first; optionally: rails scrapers:categorize_sites[100] to only classify 100 this run)"
  task :categorize_sites, [ :limit ] => :environment do |_, args|
    limit = args[:limit].presence&.to_i
    Ai::CategoryClassifier.call(limit: limit, on_progress: progress_bar("categorize"))
  end

  desc "Import sites from a Common Crawl CDX index file (default: tmp/CC-MAIN-2026-17-index)"
  task :import_common_crawl, [ :file_path ] => :environment do |_, args|
    file_path = args[:file_path] || Rails.root.join("tmp/CC-MAIN-2026-17-index")
    Importers::CommonCrawlImporter.call(file_path: file_path, on_progress: progress_bar("common_crawl"))
  end

  desc "Import sites from a plain one-hostname-per-line file (default: tmp/kz.txt)"
  task :import_domain_list, [ :file_path ] => :environment do |_, args|
    file_path = args[:file_path] || Rails.root.join("tmp/kz.txt")
    Importers::DomainListImporter.call(file_path: file_path, on_progress: progress_bar("domain_list"))
  end
end
