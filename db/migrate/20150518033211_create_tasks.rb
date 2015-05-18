class CreateTasks < ActiveRecord::Migration
  def change
    create_table :tasks do |t|
      t.string :pid
      t.string :name
      t.string :status
      t.string :progress

      t.timestamps null: false
    end
  end
end
