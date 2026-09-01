FactoryBot.define do
  factory :technology do
    sequence(:name) { |n| "Ruby on Rails #{n}" }
  end
end
