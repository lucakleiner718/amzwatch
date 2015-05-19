class CreateItems < ActiveRecord::Migration
  def change
    create_table :items do |t|
      t.string :number
      t.text :title
      t.text :description
      t.float :price
      t.float :list_price
      t.boolean :out_of_stock
      t.string :upc
      t.integer :rank
      t.string :status, default: 'new'
      t.text :url
      t.text :image_url

      t.timestamps null: false
    end
  end
end
