class AddCategoryToTechnologies < ActiveRecord::Migration[8.1]
  def change
    add_column :technologies, :category, :string
  end
end
