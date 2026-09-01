module Ai
  # Phase 1 of "one shared category list for every site" (see also the
  # Category model and Ai::CategoryClassifier for phase 2). Samples
  # SAMPLE_SIZE site descriptions, batches them through the model to
  # propose category labels, then consolidates every proposed label into
  # one final, deduplicated list, creating a Category row for each
  # (find_or_create_by, so re-running this never deletes an existing
  # category out from under sites already tagged with it).
  #
  # Samples instead of using every description, since batching tens of
  # thousands of sites for candidate labels would mean way too many
  # model calls for no real gain.
  #
  # Single public entry point, per project convention:
  #   Ai::CategoryTaxonomyBuilder.call
  class CategoryTaxonomyBuilder
    SAMPLE_SIZE = 1000
    BATCH_SIZE = 40
    TARGET_COUNT = "20-40"

    PROPOSE_SYSTEM_PROMPT = <<~PROMPT.freeze
      You are building a category taxonomy for a catalog of business
      websites. Given a batch of site descriptions, propose short (1-3
      word) category labels that describe what kind of business/site
      each one is (e.g. "Restaurant", "Online Store", "Law Firm", "News
      Media", "Software Company"). Reuse the same label across similar
      sites — don't invent a new label for every single site. Answer
      only with the requested JSON.
    PROMPT

    CONSOLIDATE_SYSTEM_PROMPT = <<~PROMPT.freeze
      You are given a long list of candidate category labels proposed
      for a business website catalog, with duplicates and near-
      duplicates (different wording for the same kind of business).
      Consolidate them into one final list of #{TARGET_COUNT} distinct,
      general categories that together cover the whole list well.
      Prefer broader, reusable labels over narrow or oddly specific
      ones. Answer only with the requested JSON.
    PROMPT

    LIST_SCHEMA = {
      type: "object",
      properties: { categories: { type: "array", items: { type: "string" } } },
      required: %w[categories]
    }.freeze

    def self.call(...) = new(...).call

    # on_progress is called once per proposal batch, as
    # on_progress.call(done_count, total_count) — the final consolidate
    # step isn't counted, it's one call at the very end.
    def initialize(on_progress: ->(*) { })
      @on_progress = on_progress
    end

    def call
      descriptions = sample_descriptions
      if descriptions.empty?
        raise "No site descriptions to build a taxonomy from — run scrapers:detect_technologies first"
      end

      batches = descriptions.each_slice(BATCH_SIZE).to_a
      candidates = batches.each_with_index.flat_map do |batch, index|
        proposed = propose(batch)
        @on_progress.call(index + 1, batches.size)
        proposed
      end

      final_list = consolidate(candidates.uniq { |label| label.downcase })
      raise "Ollama didn't return a usable taxonomy — is it running (Ai::Client.available?)?" if final_list.blank?

      final_list.each { |name| Category.find_or_create_by!(name: name) }
      Category.order(:name).pluck(:name)
    end

    private

    def sample_descriptions
      Site.where.not(description: nil).order(Arel.sql("RANDOM()")).limit(SAMPLE_SIZE).pluck(:description)
    end

    def propose(batch)
      prompt = "Site descriptions:\n#{batch.map.with_index(1) { |text, n| "#{n}. #{text}" }.join("\n")}"
      result = Ai::Client.call(system: PROPOSE_SYSTEM_PROMPT, prompt: prompt, schema: LIST_SCHEMA)
      clean_labels(result&.dig(:categories))
    end

    def consolidate(candidates)
      prompt = "Candidate labels:\n#{candidates.join(', ')}"
      result = Ai::Client.call(system: CONSOLIDATE_SYSTEM_PROMPT, prompt: prompt, schema: LIST_SCHEMA)
      clean_labels(result&.dig(:categories))
    end

    def clean_labels(labels)
      Array(labels).map { |label| label.to_s.strip }.reject(&:blank?).uniq
    end
  end
end
