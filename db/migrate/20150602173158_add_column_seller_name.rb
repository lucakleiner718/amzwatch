class AddColumnSellerName < ActiveRecord::Migration
  def change
    add_column :items, :seller_name, :string
  end
end
