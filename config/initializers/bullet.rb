if Rails.env.development? || Rails.env.test?
  Rails.application.config.after_initialize do
    Bullet.enable = true
    Bullet.alert = false
    Bullet.bullet_logger = true
    Bullet.console = true
    Bullet.rails_logger = true

    if Rails.env.test?
      Bullet.raise = true # raise an error if an N+1 query occurs in specs
    end
  end
end
