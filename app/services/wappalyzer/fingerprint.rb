require "json"

module Wappalyzer
  # One technology's compiled detection rules, loaded from Wappalyzer's
  # vendored fingerprint data (lib/wappalyzer_data/), patched with our own
  # fixes (lib/wappalyzer_supplements.json).
  #
  # Only fields checkable from a plain HTTP GET are used: headers, cookies,
  # meta tags, script src URLs, and the HTML body. Fields needing a browser
  # (dom, js, css), extra requests (dns, xhr, probe, certIssuer), or
  # another technology already detected (requires, requiresCategory) are
  # not supported — those technologies are skipped.
  Fingerprint = Struct.new(
    :name, :category, :icon, :headers, :cookies, :meta, :html, :script_src, :url,
    :implies, :excludes,
    keyword_init: true
  ) do
    class << self
      def all
        @all ||= load_all
      end

      def find(name) = all.find { |fp| fp.name == name }

      def categories
        @categories ||= JSON.parse(File.read(data_path.join("categories.json")))
      end

      private

      def category_name(id) = categories.dig(id.to_s, "name")

      def data_path
        Rails.root.join("lib/wappalyzer_data")
      end

      def load_all
        supplements = load_supplements

        data_path.join("technologies").glob("*.json").flat_map do |file|
          JSON.parse(File.read(file)).filter_map do |name, definition|
            next if definition["requires"] || definition["requiresCategory"]

            build(name, definition, supplements[name])
          end
        end
      end

      # Our own patch file for gaps in the upstream fingerprints — see
      # that file for details.
      def load_supplements
        path = Rails.root.join("lib/wappalyzer_supplements.json")
        return {} unless path.exist?

        JSON.parse(File.read(path)).except("_comment")
      end

      def build(name, definition, supplement)
        new(
          name: name,
          category: category_name(Array(definition["cats"]).first),
          icon: definition["icon"],
          headers: pattern_hash(definition["headers"], supplement&.dig("headers")),
          cookies: pattern_hash(definition["cookies"], supplement&.dig("cookies")),
          meta: pattern_hash(definition["meta"], supplement&.dig("meta")),
          html: pattern_list(definition["html"]) + pattern_list(definition["scripts"]) +
            pattern_list(supplement&.dig("html")),
          script_src: pattern_list(definition["scriptSrc"]) + pattern_list(supplement&.dig("scriptSrc")),
          url: pattern_list(definition["url"]),
          implies: implication_list(definition["implies"]),
          excludes: Array(definition["excludes"]).map { |v| v.to_s.split('\;').first }
        )
      end

      # headers/cookies/meta are keyed Hashes of pattern string(s). A
      # supplement only adds patterns, never removes any.
      def pattern_hash(raw, supplement_raw = nil)
        merged = raw.present? ? raw.transform_values { |v| pattern_list(v) } : {}
        return merged if supplement_raw.blank?

        supplement_raw.each do |key, patterns|
          merged[key] = (merged[key] || []) + pattern_list(patterns)
        end

        merged
      end

      def pattern_list(raw)
        Array(raw).filter_map { |v| Pattern.parse(v) }
      end

      # implies is a name or array of names, each optionally carrying its
      # own "\;confidence:NN" suffix. Unlike Pattern, a missing confidence
      # here means "unconditional", not "default 100" — that nil/present
      # distinction must survive parsing.
      def implication_list(raw)
        Array(raw).map do |v|
          name, *meta = v.to_s.split('\;')
          confidence = meta.filter_map { |part| part.split(":", 2) }
                           .find { |key, _| key == "confidence" }
                           &.last&.to_i

          [ name, confidence ]
        end
      end
    end
  end
end
