module Scrapers
  # Shared "polite scraping" plumbing: custom User-Agent, timeouts, retry
  # with backoff, and upserting discovered sites by url (no duplicates on
  # a re-run).
  #
  # A subclass implements #each_site and #source_name.
  #
  # Single public entry point, per project convention:
  #   Scrapers::SomeScraper.call
  class BaseScraper
    USER_AGENT = "SiteRadarBot/1.0 (+https://github.com/bekseitn/site_radar_kz)".freeze

    OPEN_TIMEOUT = 5
    TIMEOUT = 10
    MAX_ATTEMPTS = 3
    RETRY_BACKOFF = 1 # seconds, multiplied by the attempt number

    def self.call(...) = new(...).call

    # Called once per site found, as on_progress.call(count) — total isn't
    # known upfront.
    def initialize(delay: 1.0, on_progress: ->(*) { })
      @delay = delay
      @on_progress = on_progress
    end

    def call
      stats = Hash.new(0)

      each_site do |attrs|
        stats[:found] += 1
        upsert_site(attrs, stats)
        @on_progress.call(stats[:found])
      end

      log_summary(stats)
      stats
    end

    private

    # Subclasses yield one Hash of Site attributes (at least :url) per site found.
    def each_site
      raise NotImplementedError, "#{self.class} must implement #each_site"
    end

    def source_name
      raise NotImplementedError, "#{self.class} must implement #source_name"
    end

    def upsert_site(attrs, stats)
      url = attrs[:url]

      if url.blank?
        stats[:errors] += 1
        Rails.logger.warn("[#{self.class.name}] skipped a record with a blank url")
        return
      end

      # Normalize first — Site adds a trailing slash on save, so checking
      # the raw url here would miss existing records.
      url = Site.normalize_url(url)

      if Site.exists?(url: url)
        stats[:existing] += 1
      else
        Site.create!(attrs.merge(url: url, source: source_name))
        stats[:created] += 1
      end
    rescue ActiveRecord::RecordInvalid => e
      stats[:errors] += 1
      Rails.logger.warn("[#{self.class.name}] skipped #{url}: #{e.message}")
    end

    def throttle(index)
      sleep(@delay) if index.positive? && @delay.positive?
    end

    def get(url, params: nil)
      attempts = 0

      begin
        attempts += 1
        connection.get(url, params)
      rescue Faraday::Error => e
        if attempts < MAX_ATTEMPTS
          sleep(RETRY_BACKOFF * attempts) if @delay.positive?
          retry
        end

        Rails.logger.warn("[#{self.class.name}] #{url} failed: #{e.class} #{e.message}")
        nil
      end
    end

    def connection
      @connection ||= Faraday.new do |f|
        f.options.timeout = TIMEOUT
        f.options.open_timeout = OPEN_TIMEOUT
        f.headers["User-Agent"] = USER_AGENT
        f.adapter Faraday.default_adapter
      end
    end

    def log_summary(stats)
      Rails.logger.info(
        "[#{self.class.name}] " + stats.map { |key, value| "#{key}=#{value}" }.join(" ")
      )
    end
  end
end
