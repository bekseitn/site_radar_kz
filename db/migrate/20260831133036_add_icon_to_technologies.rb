class AddIconToTechnologies < ActiveRecord::Migration[8.1]
  def change
    add_column :technologies, :icon, :string
  end
end
