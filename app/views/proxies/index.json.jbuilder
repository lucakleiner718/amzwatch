json.array!(@proxies) do |proxy|
  json.extract! proxy, :id, :ip, :port, :username, :password, :status, :hit_count, :failure_count
  json.url proxy_url(proxy, format: :json)
end
