class CreateProxies < ActiveRecord::Migration
  def change
    create_table :proxies do |t|
      t.string :ip
      t.integer :port
      t.string :username
      t.string :password
      t.string :status
      t.integer :hit_count
      t.integer :failure_count

      t.timestamps null: false
    end
  end
end
