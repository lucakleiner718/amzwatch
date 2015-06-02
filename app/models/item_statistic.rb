class ItemStatistic < ActiveRecord::Base
  belongs_to :item

  def self.to_csv(path)
    update_qty_change!

    CSV.open(path, 'w') do |csv|
      csv << ['number', 'date', 'rank', 'qty left', 'qty change']
      all.joins(:item).order('item_statistics.created_at').select('items.number, item_statistics.*').each {|r|
        csv << [r.number, r.created_at, r.rank, r.qty_left, r.qty_change] 
      }
    end
  end

  def self.update_qty_change!
    sql = %Q{
      UPDATE item_statistics origin SET qty_change = (
        SELECT qty_left - origin.qty_left
        FROM item_statistics 
        WHERE item_id = origin.item_id AND id < origin.id
        ORDER by created_at DESC
        LIMIT 1
      ) WHERE qty_change IS NULL;
    }
    self.connection.execute(sql)
  end
end
