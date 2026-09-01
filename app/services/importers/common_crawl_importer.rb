require "json"

module Importers
  # Reads a Common Crawl CDX index file (JSON Lines) and creates a pending
  # Site for every unique host with a successfully crawled HTML page.
  #
  # Single public entry point, per project convention:
  #   Importers::CommonCrawlImporter.call(file_path: "tmp/CC-MAIN-2026-17-index")
  class CommonCrawlImporter
    SOURCE = "common_crawl".freeze

    def self.call(...) = new(...).call

    # Called once per unique host, as on_progress.call(done_count, total_count)
    def initialize(file_path:, country: "KZ", source: SOURCE, on_progress: ->(*) { })
      @file_path = file_path
      @country = country
      @source = source
      @on_progress = on_progress
    end

    def call
      stats = Hash.new(0)
      hosts, stats[:parse_errors] = hosts_from_file
      stats[:total_hosts] = hosts.size

      hosts.each_with_index do |host, index|
        if Site.exists?(url: site_url(host))
          stats[:existing] += 1
        else
          Site.create!(url: site_url(host), name: host, country: @country, source: @source)
          stats[:created] += 1
        end

        @on_progress.call(index + 1, hosts.size)
      end

      log_summary(stats)
      stats
    end

    private

    def hosts_from_file
      hosts = Set.new
      errors = 0

      File.foreach(@file_path) do |line|
        record = JSON.parse(line)
        next unless record["status"] == "200" && record["mime"] == "text/html"

        host = URI.parse(record["url"]).host
        hosts << host if host.present? && PublicSuffix.valid?(host, default_rule: nil)
      rescue JSON::ParserError, URI::InvalidURIError
        errors += 1
      end

      [ hosts, errors ]
    end

    def site_url(host) = "https://#{host}/"

    def log_summary(stats)
      Rails.logger.info(
        "[CommonCrawlImporter] hosts=#{stats[:total_hosts]} " \
        "created=#{stats[:created]} existing=#{stats[:existing]} " \
        "parse_errors=#{stats[:parse_errors]}"
      )
    end
  end
end
