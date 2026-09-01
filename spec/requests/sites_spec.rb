require "rails_helper"

RSpec.describe "Sites", type: :request do
  describe "GET /" do
    it "lists all sites" do
      create(:site, name: "Kazakhstan Site", status: :checked)
      create(:site, name: "Ukraine Site", status: :checked)

      get root_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Kazakhstan Site")
      expect(response.body).to include("Ukraine Site")
    end

    it "filters by city" do
      kz_site = create(:site, name: "Kazakhstan Site", status: :checked)
      kz_site.cities = [ City.create!(name: "Almaty") ]
      ua_site = create(:site, name: "Ukraine Site", status: :checked)
      ua_site.cities = [ City.create!(name: "Kyiv") ]

      get root_path, params: { city: "Almaty" }

      expect(response.body).to include("Kazakhstan Site")
      expect(response.body).not_to include("Ukraine Site")
    end

    it "shows an empty state when the filter matches nothing" do
      create(:site, name: "Kazakhstan Site", status: :checked)

      get root_path, params: { q: "no-such-site" }

      expect(response.body).to include("No sites match the selected filters.")
    end
  end
end
