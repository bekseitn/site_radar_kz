module Ai
  # Phase 2 of "one shared category list for every site" (see
  # Ai::CategoryTaxonomyBuilder for phase 1). Classifies every Site with
  # a description into one or more Category records, regardless of what
  # categories it already had. Works off the stored description; doesn't
  # re-fetch the homepage.
  #
  # Single public entry point, per project convention:
  #   Ai::CategoryClassifier.call
  class CategoryClassifier
    def self.call(...) = new(...).call

    # on_progress is called once per site, as on_progress.call(done_count,
    # total_count) — same shape as TechnologyDetector's.
    def initialize(limit: nil, on_progress: ->(*) { })
      @limit = limit
      @on_progress = on_progress
    end

    def call
      if Category.none?
        raise "No category taxonomy yet — run scrapers:build_category_taxonomy first"
      end

      stats = Hash.new(0)
      base_scope = Site.where.not(description: nil)
      scope = @limit ? base_scope.limit(@limit) : base_scope
      total = @limit ? [ base_scope.count, @limit ].min : scope.count

      scope.find_each.with_index do |site, index|
        classify(site, stats)
        @on_progress.call(index + 1, total)
      end

      log_summary(stats)
      stats
    end

    private

    def classify(site, stats)
      result = Ai::SiteAnalyzer.call(text: site.description, need_description: false, need_categories: true, need_parked: false)

      if result[:categories].present?
        # Already validated against Category names by Ai::SiteAnalyzer —
        # this just looks those rows up, it doesn't create new ones.
        site.categories = Category.where(name: result[:categories])
        stats[:classified] += 1
      else
        stats[:skipped] += 1
      end
    rescue StandardError => e
      stats[:errors] += 1
      Rails.logger.error("[Ai::CategoryClassifier] #{site.url} raised #{e.class}: #{e.message}")
    end

    def log_summary(stats)
      Rails.logger.info(
        "[Ai::CategoryClassifier] classified=#{stats[:classified]} skipped=#{stats[:skipped]} errors=#{stats[:errors]}"
      )
    end
  end
end
