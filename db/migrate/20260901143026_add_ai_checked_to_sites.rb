class AddAiCheckedToSites < ActiveRecord::Migration[8.1]
  def up
    add_column :sites, :ai_checked, :boolean, default: false, null: false

    # Every site processed so far (checked or unreachable) went through
    # the AI-enabled detector run.
    execute "UPDATE sites SET ai_checked = TRUE WHERE status IN (1, 2)" # 1 = checked, 2 = unreachable
  end

  def down
    remove_column :sites, :ai_checked
  end
end
