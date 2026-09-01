class AddAiCheckedToSites < ActiveRecord::Migration[8.1]
  def up
    add_column :sites, :ai_checked, :boolean, default: false, null: false

    # Every site checked so far went through the AI-enabled detector run.
    execute "UPDATE sites SET ai_checked = TRUE WHERE status = 1" # 1 = checked
  end

  def down
    remove_column :sites, :ai_checked
  end
end
