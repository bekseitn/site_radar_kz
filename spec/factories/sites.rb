FactoryBot.define do
  factory :site do
    sequence(:name) { |n| "Example Site #{n}" }
    sequence(:url) { |n| "https://example-#{n}.test" }
    country { "KZ" }
    source { "test" }
    status { :pending }
    last_checked_at { nil }
  end
end
