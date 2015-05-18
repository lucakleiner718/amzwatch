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
      t.string :status
      t.text :url
      t.text :image_url

      t.timestamps null: false
    end
  end
end

#DATABASE_URL=postgres://postgres:postgres@localhost:5432/amazon150517 ruby lib/amazon_scraper.rb --item="http://www.amazon.co.uk/Smith-Canova-Morelet-Flapover-92481/dp/B00QGEORVM"