require "rails_helper"

RSpec.describe "Browsing sites", type: :system do
  it "lets a visitor filter the site list by city" do
    kz_site = create(:site, name: "Kazakhstan Site", status: :checked)
    kz_site.cities = [ City.create!(name: "Almaty") ]
    ua_site = create(:site, name: "Ukraine Site", status: :checked)
    ua_site.cities = [ City.create!(name: "Kyiv") ]

    visit root_path

    expect(page).to have_content(kz_site.name)
    expect(page).to have_content(ua_site.name)

    select "Almaty", from: "city"
    click_button "Filter"

    expect(page).to have_content(kz_site.name)
    expect(page).not_to have_content(ua_site.name)
  end

  it "shows an empty state when no site matches the filter" do
    create(:site, name: "Kazakhstan Site", status: :checked)

    visit root_path(q: "no-such-site")

    expect(page).to have_content("No sites match the selected filters.")
  end
end
