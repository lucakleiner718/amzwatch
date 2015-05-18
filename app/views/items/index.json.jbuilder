json.array!(@items) do |item|
  json.extract! item, :id, :asin, :title, :description, :price, :upc, :rank, :status, :url
  json.url item_url(item, format: :json)
end
