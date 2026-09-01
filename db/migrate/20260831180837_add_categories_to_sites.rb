class AddCategoriesToSites < ActiveRecord::Migration[8.1]
  # A site can genuinely be more than one thing at once (a
  # LocalBusiness that's also a Restaurant, an Organization AI also
  # tags "Media & Publishing" and "E-commerce & Shopping" for) — see
  # TechnologyDetector/Ai::SiteAnalyzer, which used to overwrite a
  # single category column with whichever source ran last. categories
  # (json array) replaces it; existing single-category data is wrapped
  # into a one-element array rather than lost.
  def up
    add_column :sites, :categories, :json

    execute <<~SQL
      UPDATE sites SET categories = json_array(category) WHERE category IS NOT NULL
    SQL

    remove_column :sites, :category
  end

  def down
    add_column :sites, :category, :string

    execute <<~SQL
      UPDATE sites SET category = json_extract(categories, '$[0]') WHERE categories IS NOT NULL
    SQL

    remove_column :sites, :categories
  end
end
