require "rails_helper"

RSpec.describe SiteTechnology, type: :model do
  subject(:site_technology) { build(:site_technology) }

  it { is_expected.to be_valid }

  it "does not allow the same technology to be linked to a site twice" do
    site_technology.save!

    duplicate = build(:site_technology, site: site_technology.site, technology: site_technology.technology)

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:site_id]).to include("has already been taken")
  end
end
