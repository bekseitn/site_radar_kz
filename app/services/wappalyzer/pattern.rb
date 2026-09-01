module Wappalyzer
  # A single compiled Wappalyzer pattern.
  #
  # Fingerprint files encode a regex plus optional metadata in one string,
  # separated by "\;", e.g.:
  #
  #   "^WordPress(?: ([\\d.]+))?\\;version:\\1"
  #   "_session_id\\;confidence:75"
  #
  # An empty pattern ("") means "match if this key is present" — #regexp
  # is nil then, and #match? only checks presence.
  Pattern = Struct.new(:regexp, :confidence) do
    def self.parse(raw)
      return nil if raw.nil?

      source, *meta = raw.to_s.split('\;')
      confidence = 100

      meta.each do |part|
        key, value = part.split(":", 2)
        confidence = value.to_i if key == "confidence"
      end

      regexp = source.presence && compile(source)
      new(regexp, confidence)
    end

    def self.compile(source)
      # Some upstream patterns have redundant quantifiers that Ruby warns
      # about on boot; silence that expected warning.
      previous_verbose = $VERBOSE
      $VERBOSE = nil
      Regexp.new(source, Regexp::IGNORECASE)
    rescue RegexpError
      nil
    ensure
      $VERBOSE = previous_verbose
    end

    # nil regexp means presence-only — nothing left to check.
    #
    # A few vendored patterns are prone to catastrophic backtracking;
    # Regexp.timeout turns that into a TimeoutError, treated as no match.
    def match?(value)
      return true if regexp.nil?
      return false if value.blank?

      regexp.match?(value)
    rescue Regexp::TimeoutError
      false
    end
  end
end
