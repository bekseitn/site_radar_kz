require "vcr"

VCR.configure do |config|
  config.cassette_library_dir = "spec/vcr_cassettes"
  config.hook_into :webmock
  config.configure_rspec_metadata!

  # Allow requests to the local Capybara/Selenium server used by system tests.
  config.ignore_localhost = true
end
