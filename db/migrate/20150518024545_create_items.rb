class CreateItems < ActiveRecord::Migration
  def change
    create_table :items do |t|
      t.string :asin
      t.text :title
      t.text :description
      t.float :price
      t.string :upc
      t.integer :rank
      t.string :status
      t.text :url

      t.timestamps null: false
    end
  end
end
