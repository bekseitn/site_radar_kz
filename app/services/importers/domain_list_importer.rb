module Importers
  # Reads a plain text file of one hostname per line and creates a pending
  # Site for each one, pointed at "https://<host>/".
  #
  # Single public entry point, per project convention:
  #   Importers::DomainListImporter.call(file_path: "tmp/kz.txt")
  class DomainListImporter
    SOURCE = "domain_list".freeze

    def self.call(...) = new(...).call

    # Called once per line, as on_progress.call(done_count, total_count)
    def initialize(file_path:, country: "KZ", source: SOURCE, on_progress: ->(*) { })
      @file_path = file_path
      @country = country
      @source = source
      @on_progress = on_progress
    end

    def call
      stats = Hash.new(0)
      total = File.foreach(@file_path).count

      File.foreach(@file_path).with_index do |line, index|
        host = line.strip

        if host.present?
          if PublicSuffix.valid?(host, default_rule: nil)
            stats[:seen] += 1
            upsert_site(host, stats)
          else
            stats[:invalid] += 1
          end
        end

        @on_progress.call(index + 1, total)
      end

      log_summary(stats)
      stats
    end

    private

    def upsert_site(host, stats)
      url = "https://#{host}/"

      if Site.exists?(url: url)
        stats[:existing] += 1
      else
        Site.create!(url: url, name: host, country: @country, source: @source)
        stats[:created] += 1
      end
    rescue ActiveRecord::RecordInvalid => e
      stats[:invalid] += 1
      Rails.logger.warn("[DomainListImporter] skipped #{host}: #{e.message}")
    end

    def log_summary(stats)
      Rails.logger.info(
        "[DomainListImporter] seen=#{stats[:seen]} created=#{stats[:created]} " \
        "existing=#{stats[:existing]} invalid=#{stats[:invalid]}"
      )
    end
  end
end
