require "rails_helper"

RSpec.describe Scrapers::BaseScraper do
  describe "the abstract interface" do
    it "requires subclasses to implement #each_site" do
      expect { described_class.new.send(:each_site) { } }.to raise_error(NotImplementedError)
    end

    it "requires subclasses to implement #source_name" do
      expect { described_class.new.send(:source_name) }.to raise_error(NotImplementedError)
    end
  end

  describe "a concrete subclass" do
    let(:scraper_class) do
      Class.new(Scrapers::BaseScraper) do
        def initialize(rows, delay: 0)
          super(delay: delay)
          @rows = rows
        end

        private

        def source_name = "test_source"

        def each_site
          @rows.each { |row| yield row }
        end
      end
    end

    it "creates a new site with the source name attached" do
      scraper_class.new([ { url: "https://new.test", name: "New" } ]).call

      # Site normalizes a bare-path url by adding a trailing slash.
      site = Site.find_by(url: "https://new.test/")
      expect(site.name).to eq("New")
      expect(site.source).to eq("test_source")
    end

    it "does not duplicate a site that already exists" do
      create(:site, url: "https://existing.test")

      stats = scraper_class.new([ { url: "https://existing.test", name: "Existing" } ]).call

      expect(Site.where(url: "https://existing.test/").count).to eq(1)
      expect(stats[:existing]).to eq(1)
      expect(stats[:created]).to eq(0)
    end

    it "reports found/created/existing counts" do
      create(:site, url: "https://existing.test")

      stats = scraper_class.new([
        { url: "https://existing.test", name: "Existing" },
        { url: "https://new-one.test", name: "New" },
        { url: "https://new-two.test", name: "New 2" }
      ]).call

      expect(stats[:found]).to eq(3)
      expect(stats[:created]).to eq(2)
      expect(stats[:existing]).to eq(1)
    end

    it "skips a record with a blank url instead of raising" do
      stats = scraper_class.new([ { url: "", name: "No url" } ]).call

      expect(stats[:errors]).to eq(1)
      expect(Site.count).to eq(0)
    end
  end
end
