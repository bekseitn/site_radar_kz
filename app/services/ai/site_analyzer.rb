module Ai
  # Fills in whatever TechnologyDetector's deterministic extraction
  # couldn't: description, categories, cities, and likely_parked.
  # Best-effort — returns {} if Ollama isn't reachable or there's
  # nothing to work with.
  #
  # Single public entry point, per project convention:
  #   Ai::SiteAnalyzer.call(text: visible_text, need_description: true, need_categories: true)
  class SiteAnalyzer
    SYSTEM_PROMPT = <<~PROMPT.freeze
      You analyze the homepage text of a website and answer only with
      the requested JSON fields. Be concise and factual — never invent
      information the text doesn't support. If the text is too sparse
      or garbled to tell, answer with an empty string/array rather than
      guessing (except likely_parked, which should be your best
      judgment either way).
    PROMPT

    TEXT_SAMPLE_LENGTH = 4000
    MAX_CATEGORIES = 3
    MAX_CITIES = 3

    def self.call(...) = new(...).call

    def initialize(text:, need_description: true, need_categories: true, need_parked: true, need_cities: false)
      @text = text.to_s.first(TEXT_SAMPLE_LENGTH)
      @need_description = need_description
      @need_categories = need_categories
      @need_parked = need_parked
      @need_cities = need_cities
    end

    def call
      return {} if @text.blank? || required_keys.empty?

      result = Ai::Client.call(system: SYSTEM_PROMPT, prompt: prompt, schema: schema)
      return {} if result.blank?

      {
        description: (result[:description].presence if @need_description),
        categories: normalized_categories(result[:categories]),
        likely_parked: (result[:likely_parked] if @need_parked),
        cities: normalized_cities(result[:cities])
      }.compact
    end

    private

    def prompt
      instructions = [
        (@need_description ? "- description: a one-sentence, neutral summary of what this business/site offers, written in the same language as the page text." : nil),
        (@need_categories ? "- categories: #{categories_instruction}" : nil),
        (@need_parked ? "- likely_parked: true if this looks like a parked domain, registrar placeholder, \"coming soon\"/\"under construction\" page, or otherwise not a real in-use site; false otherwise." : nil),
        (@need_cities ? "- cities: an array of up to #{MAX_CITIES} Kazakhstani cities this business/site is based in or serves, in Russian (e.g. \"Алматы\", \"Астана\"), if the text says or clearly implies any; empty array otherwise." : nil)
      ].compact

      "Answer with these fields:\n#{instructions.join("\n")}\n\nHomepage text:\n#{@text}"
    end

    def categories_instruction
      base = "an array of 1-#{MAX_CATEGORIES} labels — most sites need just one, but list more if the site is genuinely more than one thing"
      if taxonomy.present?
        "#{base}, each copied verbatim from this list: #{taxonomy.join(', ')}"
      else
        "#{base}, each a short (1-3 word) business/site category label"
      end
    end

    def schema
      properties = {
        description: { type: "string" },
        categories: {
          type: "array",
          items: taxonomy.present? ? { type: "string", enum: taxonomy } : { type: "string" },
          maxItems: MAX_CATEGORIES
        },
        likely_parked: { type: "boolean" },
        cities: { type: "array", items: { type: "string" }, maxItems: MAX_CITIES }
      }.slice(*required_keys)

      { type: "object", properties: properties, required: required_keys.map(&:to_s) }
    end

    def required_keys
      [
        (:description if @need_description),
        (:categories if @need_categories),
        (:likely_parked if @need_parked),
        (:cities if @need_cities)
      ].compact
    end

    # Guards against near-matches (wrong case, stray whitespace).
    def normalized_categories(values)
      return nil unless @need_categories

      labels = Array(values).map { |value| value.to_s.strip }.reject(&:blank?)
      return labels.uniq.presence if taxonomy.blank?

      labels.filter_map { |label| taxonomy.find { |candidate| candidate.casecmp?(label) } }.uniq.presence
    end

    def normalized_cities(values)
      return nil unless @need_cities

      Array(values).map { |value| value.to_s.strip }.reject(&:blank?).uniq.presence
    end

    def taxonomy
      @taxonomy ||= Category.order(:name).pluck(:name)
    end
  end
end
