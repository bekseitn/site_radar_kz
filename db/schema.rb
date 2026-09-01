# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_08_31_181831) do
  create_table "categories", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_categories_on_name", unique: true
  end

  create_table "cities", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_cities_on_name", unique: true
  end

  create_table "languages", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_languages_on_name", unique: true
  end

  create_table "site_categories", force: :cascade do |t|
    t.integer "category_id", null: false
    t.datetime "created_at", null: false
    t.integer "site_id", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_site_categories_on_category_id"
    t.index ["site_id", "category_id"], name: "index_site_categories_on_site_id_and_category_id", unique: true
    t.index ["site_id"], name: "index_site_categories_on_site_id"
  end

  create_table "site_cities", force: :cascade do |t|
    t.integer "city_id", null: false
    t.datetime "created_at", null: false
    t.integer "site_id", null: false
    t.datetime "updated_at", null: false
    t.index ["city_id"], name: "index_site_cities_on_city_id"
    t.index ["site_id", "city_id"], name: "index_site_cities_on_site_id_and_city_id", unique: true
    t.index ["site_id"], name: "index_site_cities_on_site_id"
  end

  create_table "site_languages", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "is_primary", default: false, null: false
    t.integer "language_id", null: false
    t.integer "site_id", null: false
    t.datetime "updated_at", null: false
    t.index ["language_id"], name: "index_site_languages_on_language_id"
    t.index ["site_id", "language_id"], name: "index_site_languages_on_site_id_and_language_id", unique: true
    t.index ["site_id"], name: "index_site_languages_on_site_id"
  end

  create_table "site_technologies", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "found_in_vacancy", default: false, null: false
    t.integer "site_id", null: false
    t.integer "technology_id", null: false
    t.datetime "updated_at", null: false
    t.index ["site_id", "technology_id"], name: "index_site_technologies_on_site_id_and_technology_id", unique: true
    t.index ["site_id"], name: "index_site_technologies_on_site_id"
    t.index ["technology_id"], name: "index_site_technologies_on_technology_id"
  end

  create_table "sites", force: :cascade do |t|
    t.string "country"
    t.datetime "created_at", null: false
    t.text "description"
    t.string "email"
    t.string "favicon_url"
    t.string "image_url"
    t.datetime "last_checked_at"
    t.float "latitude"
    t.boolean "likely_parked"
    t.string "logo_url"
    t.float "longitude"
    t.string "name"
    t.boolean "noindex", default: false, null: false
    t.string "opening_hours"
    t.string "phone"
    t.float "rating"
    t.integer "review_count"
    t.json "social_links"
    t.string "source"
    t.integer "status", default: 0, null: false
    t.json "translations"
    t.datetime "updated_at", null: false
    t.string "url", null: false
    t.string "vacancy_url"
    t.index ["country"], name: "index_sites_on_country"
    t.index ["status"], name: "index_sites_on_status"
    t.index ["url"], name: "index_sites_on_url", unique: true
  end

  create_table "technologies", force: :cascade do |t|
    t.string "category"
    t.datetime "created_at", null: false
    t.string "icon"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_technologies_on_name", unique: true
  end

  add_foreign_key "site_categories", "categories"
  add_foreign_key "site_categories", "sites"
  add_foreign_key "site_cities", "cities"
  add_foreign_key "site_cities", "sites"
  add_foreign_key "site_languages", "languages"
  add_foreign_key "site_languages", "sites"
  add_foreign_key "site_technologies", "sites"
  add_foreign_key "site_technologies", "technologies"
end
