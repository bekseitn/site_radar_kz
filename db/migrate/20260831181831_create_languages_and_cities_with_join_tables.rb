class CreateLanguagesAndCitiesWithJoinTables < ActiveRecord::Migration[8.1]
  # Same reasoning as categories (see CreateCategoriesAndSiteCategories):
  # a real join table instead of a scalar column, matching
  # Technology/SiteTechnology. Two genuine many-to-many relationships
  # were living in scalar-ish columns:
  #   - language (a single string) + available_languages (a json array
  #     of "also available in") really are one relationship — "which
  #     languages does this site declare" — just with one of them
  #     flagged as the primary one. Unified into site_languages.is_primary
  #     rather than keeping two separate representations of overlapping
  #     data.
  #   - city (a single string) turns out not to always be single — a
  #     site can legitimately serve/list more than one city (a delivery
  #     business, a chain with multiple branches, ...). site_cities has
  #     no is_primary equivalent — every listed city is just a city the
  #     site is associated with.
  def up
    create_table :languages do |t|
      t.string :name, null: false
      t.timestamps
    end
    add_index :languages, :name, unique: true

    create_table :site_languages do |t|
      t.references :site, null: false, foreign_key: true
      t.references :language, null: false, foreign_key: true
      t.boolean :is_primary, null: false, default: false
      t.timestamps
    end
    add_index :site_languages, [ :site_id, :language_id ], unique: true

    create_table :cities do |t|
      t.string :name, null: false
      t.timestamps
    end
    add_index :cities, :name, unique: true

    create_table :site_cities do |t|
      t.references :site, null: false, foreign_key: true
      t.references :city, null: false, foreign_key: true
      t.timestamps
    end
    add_index :site_cities, [ :site_id, :city_id ], unique: true

    # languages: reference rows from both the primary language and
    # every entry in available_languages.
    execute <<~SQL
      INSERT INTO languages (name, created_at, updated_at)
      SELECT DISTINCT sites.language, datetime('now'), datetime('now')
      FROM sites WHERE sites.language IS NOT NULL
    SQL
    execute <<~SQL
      INSERT INTO languages (name, created_at, updated_at)
      SELECT DISTINCT je.value, datetime('now'), datetime('now')
      FROM sites, json_each(sites.available_languages) AS je
      WHERE sites.available_languages IS NOT NULL
        AND je.value NOT IN (SELECT name FROM languages)
    SQL

    # site_languages: the primary language, flagged...
    execute <<~SQL
      INSERT INTO site_languages (site_id, language_id, is_primary, created_at, updated_at)
      SELECT sites.id, languages.id, TRUE, datetime('now'), datetime('now')
      FROM sites
      JOIN languages ON languages.name = sites.language
      WHERE sites.language IS NOT NULL
    SQL
    # ...and every available_languages entry, unless it's already the
    # primary one for that same site (the unique index would otherwise
    # reject the second insert for that pair).
    execute <<~SQL
      INSERT INTO site_languages (site_id, language_id, is_primary, created_at, updated_at)
      SELECT DISTINCT sites.id, languages.id, FALSE, datetime('now'), datetime('now')
      FROM sites, json_each(sites.available_languages) AS je
      JOIN languages ON languages.name = je.value
      WHERE sites.available_languages IS NOT NULL
        AND NOT EXISTS (
          SELECT 1 FROM site_languages sl
          WHERE sl.site_id = sites.id AND sl.language_id = languages.id
        )
    SQL

    execute <<~SQL
      INSERT INTO cities (name, created_at, updated_at)
      SELECT DISTINCT sites.city, datetime('now'), datetime('now')
      FROM sites WHERE sites.city IS NOT NULL
    SQL
    execute <<~SQL
      INSERT INTO site_cities (site_id, city_id, created_at, updated_at)
      SELECT sites.id, cities.id, datetime('now'), datetime('now')
      FROM sites
      JOIN cities ON cities.name = sites.city
      WHERE sites.city IS NOT NULL
    SQL

    remove_column :sites, :language
    remove_column :sites, :available_languages
    remove_column :sites, :city
  end

  def down
    add_column :sites, :language, :string
    add_column :sites, :available_languages, :json
    add_column :sites, :city, :string

    execute <<~SQL
      UPDATE sites SET language = (
        SELECT languages.name FROM site_languages
        JOIN languages ON languages.id = site_languages.language_id
        WHERE site_languages.site_id = sites.id AND site_languages.is_primary = TRUE
        LIMIT 1
      )
    SQL
    execute <<~SQL
      UPDATE sites SET available_languages = (
        SELECT json_group_array(languages.name) FROM site_languages
        JOIN languages ON languages.id = site_languages.language_id
        WHERE site_languages.site_id = sites.id AND site_languages.is_primary = FALSE
      )
      WHERE EXISTS (
        SELECT 1 FROM site_languages WHERE site_languages.site_id = sites.id AND is_primary = FALSE
      )
    SQL
    execute <<~SQL
      UPDATE sites SET city = (
        SELECT cities.name FROM site_cities
        JOIN cities ON cities.id = site_cities.city_id
        WHERE site_cities.site_id = sites.id
        LIMIT 1
      )
    SQL

    drop_table :site_languages
    drop_table :languages
    drop_table :site_cities
    drop_table :cities
  end
end
