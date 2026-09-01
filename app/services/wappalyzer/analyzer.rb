module Wappalyzer
  # Runs every Wappalyzer::Fingerprint against one HTTP response and
  # returns the technologies it detects. A technology counts as detected
  # if any single one of its patterns matches — confidence is just
  # metadata, not a threshold, except for conditional "implies" edges
  # (needs confidence >= 50 to fire). "excludes" then removes anything a
  # detected technology rules out.
  class Analyzer
    IMPLIES_CONFIDENCE_THRESHOLD = 50

    def self.call(response) = new(response).call

    def initialize(response)
      @headers = response.headers
      @html = response.body.to_s.scrub
      @doc = Nokogiri::HTML(@html)
      @cookies = parse_cookies(@headers["set-cookie"])
      @meta = extract_meta
      @script_srcs = extract_script_srcs
    end

    def call
      detected = Set.new

      Fingerprint.all.each do |fp|
        detected << fp.name if match?(fp)
      end

      apply_implies(detected)

      apply_excludes(detected.to_a).map do |name|
        fp = Fingerprint.find(name)
        { name: name, category: fp&.category, icon: fp&.icon }
      end
    end

    private

    def match?(fingerprint)
      match_hash?(fingerprint.headers, @headers) ||
        match_hash?(fingerprint.cookies, @cookies) ||
        match_hash?(fingerprint.meta, @meta) ||
        match_list?(fingerprint.html, [ @html ]) ||
        match_list?(fingerprint.script_src, @script_srcs)
    end

    def match_hash?(patterns_by_key, values_by_key)
      return false if patterns_by_key.blank?

      patterns_by_key.any? do |key, patterns|
        value = values_by_key[key]
        value && patterns.any? { |pattern| pattern.match?(value) }
      end
    end

    def match_list?(patterns, values)
      return false if patterns.blank? || values.blank?

      patterns.any? { |pattern| values.any? { |value| pattern.match?(value) } }
    end

    # Breadth-first over "implies" edges so implied technologies can chain
    # further implies. Each technology is enqueued once, so cycles can't loop forever.
    def apply_implies(detected)
      queue = detected.to_a

      until queue.empty?
        name = queue.shift

        Fingerprint.find(name)&.implies&.each do |implied_name, confidence|
          next if detected.include?(implied_name)
          next if confidence && confidence < IMPLIES_CONFIDENCE_THRESHOLD

          detected << implied_name
          queue << implied_name
        end
      end
    end

    def apply_excludes(detected_names)
      excluded = detected_names.flat_map { |name| Fingerprint.find(name)&.excludes || [] }
      detected_names - excluded
    end

    # Set-Cookie can bundle multiple cookies comma-joined, and Expires
    # dates also contain commas — only match a name right after a real
    # header boundary (string start, or ", " before "name=value").
    def parse_cookies(set_cookie_header)
      Array(set_cookie_header).join(", ").scan(/(?:\A|,\s*)([^=;,\s]+)=([^;,]*)/).to_h
    end

    def extract_meta
      @doc.css("meta[name]").each_with_object({}) do |node, hash|
        name = node["name"]&.downcase
        hash[name] ||= node["content"] if name.present?
      end
    end

    def extract_script_srcs
      @doc.css("script[src]").filter_map { |node| node["src"] }
    end
  end
end
