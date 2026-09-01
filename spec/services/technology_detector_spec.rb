require "rails_helper"

RSpec.describe TechnologyDetector do
  def stub_homepage(url, status: 200, headers: {}, body: "<html><body>hi</body></html>")
    stub_request(:get, url).to_return(status: status, headers: headers, body: body)
  end

  def stub_vacancy_paths(url, found_at: nil, mentioning: "We are hiring a Ruby on Rails developer")
    TechnologyDetector::VACANCY_PATHS.each do |path|
      full_url = "#{url.chomp('/')}#{path}"

      if path == found_at
        stub_request(:get, full_url).to_return(status: 200, body: "<html><body>#{mentioning}</body></html>")
      else
        stub_request(:get, full_url).to_return(status: 404, body: "not found")
      end
    end
  end

  def run_detector
    described_class.call(delay: 0)
  end

  describe "detecting Ruby on Rails" do
    it "recognizes the X-Runtime header, the Rails CSRF meta tag and the session cookie" do
      site = create(:site, url: "https://rails-app.test")
      stub_homepage(
        site.url,
        headers: {
          "X-Runtime" => "0.012345",
          "Set-Cookie" => "_rubyradar_session=abc123; path=/; HttpOnly"
        },
        body: '<html><head><meta name="csrf-param" content="authenticity_token"></head></html>'
      )
      stub_vacancy_paths(site.url)

      run_detector
      site.reload

      expect(site.status).to eq("checked")
      expect(site.technologies.pluck(:name)).to contain_exactly("Ruby on Rails", "Ruby")
    end

    it "recognizes fingerprinted Rails/Propshaft asset paths" do
      site = create(:site, url: "https://rails-assets.test")
      stub_homepage(site.url, body: '<script src="/assets/application-908e25f4bf641868d8683022a5b62f54/.js"></script>')
      stub_vacancy_paths(site.url)

      run_detector
      site.reload

      expect(site.technologies.pluck(:name)).to include("Ruby on Rails")
    end
  end

  describe "detecting plain Ruby" do
    it "recognizes a Server header naming the Ruby interpreter, without Rails-specific signals" do
      site = create(:site, url: "https://sinatra-app.test")
      stub_homepage(site.url, headers: { "Server" => "Ruby/3.2.0" })
      stub_vacancy_paths(site.url)

      run_detector
      site.reload

      expect(site.technologies.pluck(:name)).to contain_exactly("Ruby")
    end
  end

  describe "no Ruby/Rails signal" do
    it "leaves the site checked without any technology" do
      site = create(:site, url: "https://plain-site.test")
      stub_homepage(site.url)
      stub_vacancy_paths(site.url)

      run_detector
      site.reload

      expect(site.status).to eq("checked")
      expect(site.technologies).to be_empty
    end
  end

  describe "vacancy page detection" do
    it "stores the vacancy_url and flags found_in_vacancy when a vacancy page mentions Ruby" do
      site = create(:site, url: "https://hiring-rubyists.test", vacancy_url: nil)
      stub_homepage(site.url, headers: { "Server" => "Ruby/3.2.0" })
      stub_vacancy_paths(site.url, found_at: "/careers")

      run_detector
      site.reload

      expect(site.vacancy_url).to eq("https://hiring-rubyists.test/careers")
      site_technology = site.site_technologies.joins(:technology).find_by(technologies: { name: "Ruby" })
      expect(site_technology.found_in_vacancy).to be true
    end
  end

  describe "unreachable sites" do
    it "marks a site unreachable on a server error" do
      site = create(:site, url: "https://broken-site.test")
      stub_homepage(site.url, status: 500)

      run_detector
      site.reload

      expect(site.status).to eq("unreachable")
      expect(site.technologies).to be_empty
    end

    it "marks a site unreachable when the connection fails" do
      site = create(:site, url: "https://unresolvable-site.test")
      stub_request(:get, site.url).to_raise(Faraday::ConnectionFailed)

      run_detector
      site.reload

      expect(site.status).to eq("unreachable")
    end

    it "marks a site unreachable on a TLS error without aborting the rest of the batch" do
      broken = create(:site, url: "https://bad-cert-site.test")
      stub_request(:get, broken.url).to_raise(Faraday::SSLError)

      healthy = create(:site, url: "https://after-the-broken-one.test")
      stub_homepage(healthy.url)
      stub_vacancy_paths(healthy.url)

      run_detector
      broken.reload
      healthy.reload

      expect(broken.status).to eq("unreachable")
      expect(healthy.status).to eq("checked")
    end
  end

  describe "malformed responses" do
    it "does not crash and does not abort the batch on invalid UTF-8 in the body" do
      invalid_utf8 = "<html>\xFF\xFE broken encoding</html>".dup.force_encoding("UTF-8")
      broken = create(:site, url: "https://invalid-encoding.test")
      stub_homepage(broken.url, body: invalid_utf8)
      stub_vacancy_paths(broken.url)

      healthy = create(:site, url: "https://after-invalid-encoding.test")
      stub_homepage(healthy.url)
      stub_vacancy_paths(healthy.url)

      expect { run_detector }.not_to raise_error
      broken.reload
      healthy.reload

      expect(broken.status).to eq("checked")
      expect(healthy.status).to eq("checked")
    end
  end

  describe "idempotency" do
    it "does not create duplicate site_technologies when a site is checked twice" do
      site = create(:site, url: "https://rails-app-2.test")
      stub_homepage(site.url, body: '<html><head><meta name="csrf-param" content="authenticity_token"></head></html>')
      stub_vacancy_paths(site.url)

      run_detector
      site.update!(status: :pending) # simulate a re-check
      run_detector

      expect(site.site_technologies.count).to eq(2) # Ruby on Rails + Ruby, no duplicates
    end
  end

  describe "scope" do
    it "only processes sites with status pending" do
      create(:site, url: "https://already-checked.test", status: :checked)

      expect(Faraday).not_to receive(:new)

      run_detector
    end
  end
end
