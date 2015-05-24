class AddColumnsItem < ActiveRecord::Migration
  def change
    add_column :items, :sizes, :text
    add_column :items, :colors, :text
    add_column :item_statistics, :qty_change, :integer
  end
end
