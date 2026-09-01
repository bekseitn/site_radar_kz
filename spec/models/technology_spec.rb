require "rails_helper"

RSpec.describe Technology, type: :model do
  subject(:technology) { build(:technology) }

  it { is_expected.to be_valid }

  describe "validations" do
    it "requires a name" do
      technology.name = nil

      expect(technology).not_to be_valid
      expect(technology.errors[:name]).to include("can't be blank")
    end

    it "requires a unique name" do
      create(:technology, name: "Ruby on Rails")

      duplicate = build(:technology, name: "Ruby on Rails")

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:name]).to include("has already been taken")
    end
  end

  describe "associations" do
    it "can be linked to sites through site_technologies" do
      site = create(:site)
      create(:site_technology, site: site, technology: technology.tap(&:save!))

      expect(technology.sites).to contain_exactly(site)
    end
  end
end
