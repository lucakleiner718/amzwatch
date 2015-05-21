class CreateItemStatistics < ActiveRecord::Migration
  def change
    create_table :item_statistics do |t|
      t.integer :qty_left
      t.integer :rank

      t.timestamps null: false
    end

    add_reference :item_statistics, :item, index: true
  end
end
