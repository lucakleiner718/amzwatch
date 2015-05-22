class ItemStatistic < ActiveRecord::Base
  belongs_to :item

  def self.to_csv(path)
    CSV.open(path, 'w') do |csv|
      csv << ['number', 'date', 'rank', 'qty left']
      all.joins(:item).select('items.number, item_statistics.*').each {|r|
        csv << [r.number, r.created_at, r.rank, r.qty_left] 
      }
    end
  end
end
