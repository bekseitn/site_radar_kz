module Ai
  # Given the <a href> links found on a site's homepage, asks the local
  # model to pick out two things TechnologyDetector's static extraction
  # can miss, in one call:
  #   - which single link, if any, leads to a careers/jobs/vacancies page
  #   - which links, if any, are a language switcher to other locale
  #     versions of the site
  #
  # Best-effort — returns {} (not raises) if Ollama isn't reachable,
  # there are no links to look at, or the model points at something it
  # wasn't shown.
  #
  # Single public entry point, per project convention:
  #   Ai::LinkAnalyzer.call(links: [{ text: "Careers", href: "/jobs" }, ...])
  class LinkAnalyzer
    SYSTEM_PROMPT = <<~PROMPT.freeze
      You are given the links found on a company website's homepage
      (link text and href). Identify:
      - vacancy_href: which single link, if any, most likely leads to a
        careers/jobs/vacancies page
      - language_links: which links, if any, are a language switcher
        pointing at other language/locale versions of this same site
        (not links to unrelated pages) — for each, give its href and
        its ISO 639-1 language code (e.g. "kk" for Kazakh, not the
        country code "kz")
      Answer only with the requested JSON. Use empty values (an empty
      string, an empty array) for anything you find no evidence for —
      never invent a link that wasn't shown to you.
    PROMPT

    MAX_LINKS = 80

    SCHEMA = {
      type: "object",
      properties: {
        vacancy_href: { type: "string" },
        language_links: {
          type: "array",
          items: {
            type: "object",
            properties: { language: { type: "string" }, href: { type: "string" } },
            required: %w[language href]
          }
        }
      },
      required: %w[vacancy_href language_links]
    }.freeze

    def self.call(...) = new(...).call

    def initialize(links:)
      @links = links.first(MAX_LINKS)
      @hrefs = @links.map { |link| link[:href] }
    end

    def call
      return {} if @links.empty?

      result = Ai::Client.call(system: SYSTEM_PROMPT, prompt: prompt, schema: SCHEMA)
      return {} if result.blank?

      { vacancy_href: trusted_href(result[:vacancy_href]), language_codes: language_codes(result[:language_links]) }.compact
    end

    private

    def prompt
      lines = @links.map { |link| "- text: #{link[:text].presence || '(no text)'}, href: #{link[:href]}" }
      "Links found on the homepage:\n#{lines.join("\n")}"
    end

    # Only trusts an href the model was actually shown — guards against
    # it inventing a plausible-looking path that was never on the page.
    def trusted_href(href)
      return nil if href.blank?

      @hrefs.find { |candidate| candidate == href }
    end

    # "kz" for "Kazakh" is a common mix-up with the country code (the
    # language code is "kk") — the prompt says so explicitly, but this
    # catches it in code too rather than trusting that alone.
    LANGUAGE_CODE_FIXUPS = { "kz" => "kk" }.freeze

    def language_codes(language_links)
      Array(language_links).filter_map do |entry|
        next unless trusted_href(entry[:href])

        code = entry[:language].to_s.strip.downcase.presence
        code && LANGUAGE_CODE_FIXUPS.fetch(code, code)
      end.uniq.presence
    end
  end
end
