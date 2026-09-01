require "rails_helper"

RSpec.describe Importers::CommonCrawlImporter do
  let(:file_path) { Rails.root.join("spec/fixtures/files/common_crawl_sample.jsonl") }

  it "creates one pending site per host that has a successfully crawled HTML page" do
    described_class.call(file_path: file_path)

    expect(Site.pluck(:url)).to contain_exactly("https://example.kz/", "https://newsite.kz/")
  end

  it "ignores hosts with no successful text/html crawl (redirect-only, 404, non-HTML)" do
    described_class.call(file_path: file_path)

    expect(Site.exists?(url: "https://onlyredirect.kz/")).to be false
    expect(Site.exists?(url: "https://notfound.kz/")).to be false
    expect(Site.exists?(url: "https://asset-only.kz/")).to be false
  end

  it "sets name, country and source on the created site" do
    described_class.call(file_path: file_path)

    site = Site.find_by(url: "https://example.kz/")
    expect(site.name).to eq("example.kz")
    expect(site.country).to eq("KZ")
    expect(site.source).to eq("common_crawl")
    expect(site.status).to eq("pending")
  end

  it "collapses multiple crawled pages of the same host into a single site" do
    described_class.call(file_path: file_path)

    expect(Site.where(url: "https://example.kz/").count).to eq(1)
  end

  it "does not create a duplicate when the site already exists" do
    create(:site, url: "https://example.kz/")

    expect { described_class.call(file_path: file_path) }
      .to change(Site, :count).by(1) # only newsite.kz is new

    expect(Site.where(url: "https://example.kz/").count).to eq(1)
  end

  it "reports stats including malformed lines as parse errors" do
    stats = described_class.call(file_path: file_path)

    expect(stats[:total_hosts]).to eq(2)
    expect(stats[:created]).to eq(2)
    expect(stats[:parse_errors]).to eq(1)
  end
end
