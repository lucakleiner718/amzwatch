class CreateProxies < ActiveRecord::Migration
  def change
    create_table :proxies do |t|
      t.string :ip
      t.integer :port
      t.string :username
      t.string :password
      t.string :status, default: 'alive'
      t.integer :hit_count, default: 0
      t.integer :failure_count, default: 0

      t.timestamps null: false
    end
  end
end
