Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # An optional /kk or /en prefix selects that locale (see
  # ApplicationController#set_locale) — the default locale (Russian)
  # stays unprefixed, so "/" and "/sites/123" keep working exactly as
  # before, only "/kk/" and "/en/" are new.
  scope "(:locale)", locale: /kk|en/ do
    resources :sites, only: [ :index, :show ]
    get "stats", to: "stats#index", as: :stats

    # Defines the root path route ("/")
    root "sites#index"
  end
end
