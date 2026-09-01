require "rails_helper"

RSpec.describe Site, type: :model do
  subject(:site) { build(:site) }

  it { is_expected.to be_valid }

  describe "validations" do
    it "requires a url" do
      site.url = nil

      expect(site).not_to be_valid
      expect(site.errors[:url]).to include("can't be blank")
    end

    it "requires a unique url" do
      create(:site, url: "https://example.test")

      duplicate = build(:site, url: "https://example.test")

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:url]).to include("has already been taken")
    end
  end

  describe "status" do
    it "defaults to pending" do
      expect(Site.new.status).to eq("pending")
    end

    it "exposes the enum values" do
      expect(Site.statuses.keys).to contain_exactly("pending", "checked", "unreachable")
    end
  end

  describe "associations" do
    it "can be linked to technologies through site_technologies" do
      technology = create(:technology)
      create(:site_technology, site: site.tap(&:save!), technology: technology)

      expect(site.technologies).to contain_exactly(technology)
    end

    it "destroys its site_technologies when destroyed" do
      site.save!
      site_technology = create(:site_technology, site: site)

      expect { site.destroy }.to change(SiteTechnology, :count).by(-1)
      expect(SiteTechnology.exists?(site_technology.id)).to be false
    end
  end
end
