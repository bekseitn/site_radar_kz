class CreateCategoriesAndSiteCategories < ActiveRecord::Migration[8.1]
  # A real join table, not a JSON array column — same shape as
  # Technology/SiteTechnology, for the same reason: a category is a
  # shared, reusable label many sites point at (not a per-site blob),
  # so filtering ("sites in this category"), counting, and building the
  # dropdown of known categories are all a plain join/query instead of
  # SQLite JSON-function gymnastics. This immediately replaces
  # sites.categories (json), added earlier today — that was the wrong
  # shape for what turned out to be a many-to-many relationship.
  def up
    create_table :categories do |t|
      t.string :name, null: false
      t.timestamps
    end
    add_index :categories, :name, unique: true

    create_table :site_categories do |t|
      t.references :site, null: false, foreign_key: true
      t.references :category, null: false, foreign_key: true
      t.timestamps
    end
    add_index :site_categories, [ :site_id, :category_id ], unique: true

    execute <<~SQL
      INSERT INTO categories (name, created_at, updated_at)
      SELECT DISTINCT je.value, datetime('now'), datetime('now')
      FROM sites, json_each(sites.categories) AS je
      WHERE sites.categories IS NOT NULL
    SQL

    execute <<~SQL
      INSERT INTO site_categories (site_id, category_id, created_at, updated_at)
      SELECT DISTINCT sites.id, categories.id, datetime('now'), datetime('now')
      FROM sites, json_each(sites.categories) AS je
      JOIN categories ON categories.name = je.value
      WHERE sites.categories IS NOT NULL
    SQL

    remove_column :sites, :categories
  end

  def down
    add_column :sites, :categories, :json

    execute <<~SQL
      UPDATE sites SET categories = (
        SELECT json_group_array(categories.name)
        FROM site_categories
        JOIN categories ON categories.id = site_categories.category_id
        WHERE site_categories.site_id = sites.id
      )
      WHERE EXISTS (SELECT 1 FROM site_categories WHERE site_categories.site_id = sites.id)
    SQL

    drop_table :site_categories
    drop_table :categories
  end
end
