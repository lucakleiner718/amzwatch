raise "DATABASE_URL not set" unless ENV['DATABASE_URL']

require 'optparse'
require 'rubygems'
require 'active_record'
require 'mechanize'
require 'zlib'
require 'timeout'
require 'httparty'
require 'uri'
require 'date'

$options = {}
parser = OptionParser.new("", 24) do |opts|
  opts.banner = "\nScraper 1.0\nAuthor: Louis (Skype: louisprm)\n\n"

  opts.on("-t", "--task ID", "Task ID") do |v|
    $options[:task] = v
  end

  opts.on("-u", "--url URL", "") do |v|
    $options[:url] = v
  end

  opts.on("-d", "--delay DELAY", "DELAY in millisecond") do |v|
    $options[:delay] = v
  end

  opts.on("-i", "--image-store PATH", "") do |v|
    $options[:image_store] = v
  end

  opts.on("--item URL", "Scrape individual item") do |v|
    $options[:item] = v
  end

  opts.on("-l", "--log LOG", "") do |v|
    $options[:log] = v
  end

  opts.on_tail('-h', '--help', 'Displays this help') do
		puts opts, "", help
    exit
	end
end

def help
  return <<-eos

GUIDELINE
-------------------------------------------------------
The scraper package includes two scripts

  1. scrape.rb: scrape data from the internet and store to a local database file
  2. export.rb: read the local database and generate the Excel/CSV output

Procedures:

  1. Run the scrape script and store scraped data to local database file main.db
	   
        ruby scrape.rb --output=main.db

  2. After the scraper script is done, run the export.rb script to read the main.db
     database and generate the Excel file data.xls

        ruby export.rb --input=main.db --output=/tmp/data.xls

Notes:

- The scrape.rb script supports resuming. Just run the script over and over again
  in case of any failure (due to internet connection problem for instance)to have
  it start from where it left off. Be sure to specify the same output database file
- As the scrape script stores items ony-by-one, you can run the export script
  even when the scraping process is not complete yet. Then it will export available
  items in the local database
 
eos
end

begin
  parser.parse!
rescue SystemExit => ex
  exit
rescue Exception => ex
  log "\nERROR: #{ex.message}\n\nRun ruby crawler.rb -h for help\n\n"
  exit
end

$options[:delay] ||= 2
$options[:delay] = $options[:delay].to_i

$logger = Logger.new($options[:log] || '/tmp/scraper.log')

class String
  def floatify
    return nil if self.nil?
    return nil if self.empty?
    return self.strip.gsub(/[^0-9\.]/, '').to_f
  end

  def deflate
    Zlib.deflate(self)
  end

  def inflate
    Zlib.inflate(self)
  end

  def fix
    self.encode!('UTF-8', :undef => :replace, :invalid => :replace, :replace => "")
  end

  def html2text
    r = self.strip
    # strip <style>, <script> tag
    r.gsub!(/<style\s.*>.*<\/style>/m, '')
    r.gsub!(/<script\s.*>.*<\/script>/m, '')

    # replace <tag>text</tag> with text\n
    r.gsub!(/<[a-zA-Z0-9]+\s*[^>]*>/, '')
    r.gsub!(/<\/[a-zA-Z0-9]+>/, "\n")

    # replace html entities with chars
    {'&amp;' => '&'}.each do |k,v|
      r.gsub!(k, v)
    end

    # strip redundant spaces
    #r.gsub!(/^\s+/, "")
    #r.gsub!(/\s+$/, "")
    #r.gsub!(/[\t\n]+/, "\n")
    #r.gsub!(/[\n]+/, "\n")

    return r
  end
end

ActiveRecord::Base.establish_connection(
  ENV['DATABASE_URL']
)

class Item < ActiveRecord::Base
  NEW = 'new'
  IN_PROGRESS = 'in_progress'
  DONE = 'done'
  FAILED = 'failed'
  
  scope :failed, -> { where(status: FAILED) }
  scope :in_progress, -> { where(status: IN_PROGRESS) }
  scope :done, -> { where(status: DONE) }
  scope :_new, -> { where(status: NEW) }
  
  UK = 'UK'
  US = 'US'

  def amazonsite
    if self.uk?
      return 'http://www.amazon.co.uk'
    else
      return 'http://www.amazon.com'
    end
  end

  def uk?
    return false unless self.country
    return self.country.upcase == UK
  end

  def us?
    return false unless self.country
    return self.country.upcase == US
  end

  def get_url
    if self.url.blank?
      return "#{self.amazonsite}/dp/#{self.number}"
    else
      return self.url
    end
  end
end

class Category < ActiveRecord::Base
end

class Task < ActiveRecord::Base
  belongs_to :category
  RUNNING = 'running'
  DEAD = 'dead'
  DONE = 'done'
  STOPPED = 'stopped'
  FAILED = 'failed'

  def log(msg)
    self.progress ||= ''
    self.progress += "#{Time.now.to_s}: #{msg}\n"
  end
end

class Setting < ActiveRecord::Base
  def self.get(name, cls)
    Kernel.send cls.name, self.find_by_name(name).value
  end
end

class Proxy < ActiveRecord::Base
  scope :alive, -> { where(status: 'alive') }
  scope :dead, -> { where(status: 'dead') }

  def mark_as_dead!
    self.status = 'dead'
    self.save!
  end

  def self.to_array
    self.all.map{|e| [e.ip, e.port, e.username, e.password]}
  end
end


# Overwrite the Mechanize class to support proxy switching
require 'mechanize'
require 'logger'

# Overwrite the Mechanize class to support proxy switching
Mechanize.class_eval do 
  class ProxyList
    attr_reader :proxies, :current

    class Proxy
      attr_reader :host, :port, :username, :passwd
      attr_reader :error, :hit_count, :failure_count, :alive
      attr_reader :events

      def initialize(host, port, username, passwd)
        @host = host
        @port = port.to_s
        @username = username
        @passwd = passwd
        @hit_count = 0
        @failure_count = 0
        @alive = true
        @current = nil
        @events = {}
      end

      def on(event, block)
        @events[event] = block
      end

      def notify(event, *args)
        @events[event].call(*args)
      end

      def increase_hit_count!
        @hit_count += 1
        notify :hit, self
        $logger.info "Done! #{self} HIT: #{self.hit_count}, FAILURE: #{self.failure_count} "
      end

      def increase_failure_count!
        @failure_count += 1
        notify :failure, self
        $logger.warn "Failed! #{self} HIT[#{self.hit_count}], FAILURE[#{self.failure_count}]"
      end

      def mark_dead!
        @alive = false
        notify :dead, self
        $logger.warn "Mark #{self} as dead"
      end

      def alive?
        @alive
      end

      def to_a
        return [@host, @port, @username, @passwd]
      end

      def to_s
        "[#{self.to_a.reject(&:nil?).join(":")}]"
      end

      def equal?(proxy)
        return false if proxy.nil?
        self.host == proxy.host and self.port == proxy.port
      end

      def valid?
        if @host.nil? or @host !~ /\A(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})\Z/
          @error = "Invalid host"
        end

        if @port.nil? or @port !~ /[0-9]+/
          @error = "Invalid port"
        end

        return @error.nil?
      end
    end

    def initialize
      @proxies = []
      @current = nil
    end

    def add(proxy)
      @proxies << proxy
    end
    
    def next_proxy
      @current = @proxies.select{|e| e.alive? && !e.equal?(current) }.sample
      return @current
    end

    def self.load(arg)
      list = self.new
      if arg.is_a?(String)
        lines = IO.read(arg).split(/[\r\n]+/).select{|line| line[/^\s*#/].nil? }.map{|line| line.split(":").map{|e| e.strip} }
      else # Array
        lines = arg
      end
      lines.each do |line|
        host, port, username, passwd = line
        proxy = Proxy.new(host, port, username.blank? ? nil : username, passwd.blank? ? nil : passwd)

        if proxy.valid?
          list.add(proxy)
          $logger.info "Proxy added #{proxy}"
        else
          $logger.warn "Invalid proxy #{proxy}: #{proxy.error}"
        end
      end

      return list
    end
  end

  def try(&block)
    loop do
      begin
        if @list.current.nil?
          $logger.info "Using direct connection"
        else
          $logger.info "Using proxy #{@list.current}"
        end
        r = Timeout.timeout(10) { yield(self) }
        @list.current.increase_hit_count! if @list.current
        next_proxy
        return r
      rescue Net::HTTP::Persistent::Error => ex
        # proxy dead
        @list.current.mark_dead! if @list.current
        next_proxy
      rescue Exception => ex # cần làm rõ do Exception nào mà mark-proxy-as-dead, có thể có tr hợp lỗi do website
        $logger.warn("Error: " + ex.message.split(/[\r\n]+/).first)
        @list.current.increase_failure_count! if @list.current
        next_proxy
      end
    end
  end

  def load_proxies(path)
    @list = ProxyList.load(path)
    next_proxy
  end

  def proxy_list
    @list
  end

  def next_proxy
    proxy = @list.next_proxy
    if proxy.nil?
      self.set_proxy nil, nil
    else
      self.set_proxy(*proxy.to_a)
    end
  end

  def on(event, &block)
    @list.proxies.each do |proxy|
      proxy.on(event, block)
    end
  end
end

HTTParty::Response.class_eval do
  def parser
    Nokogiri::HTML(self.body)
  end
end

class WClient
  include HTTParty
  follow_redirects false

  attr_accessor :headers

  def initialize
    @headers = {
      'Accept' => 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
      'Accept-Encoding' => 'gzip,deflate,sdch',
      'Accept-Language' => 'en-US,en;q=0.8,vi;q=0.6',
      'Cache-Control' => 'max-age=0',
      'Connection' => 'keep-alive',
      #'Host' => 'www.amazon.com',
      #'Origin' => 'http://www.amazon.com',
      #'Referer' => 'http://www.amazon.com/gp/cart/view.html/ref=lh_cart_vc_btn',
      'User-Agent' => 'Mozilla/5.0 (Windows NT 6.3; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/43.0.2357.65 Safari/537.36',
      'X-AUI-View' => 'Desktop',
      'X-Requested-With' => 'XMLHttpRequest'
    }
    
    @cookie = {}
  end

  def get(url)
    
    while true # handle redirect
      @headers['Host'] = URI(url).host
      
      response = self.class.get(url, :headers => @headers)
      update_cookie(response, url)
    
      if [301, 302].include? response.code 
        p "redirecting to " + response['location']
        url = response['location']
      else
        break
      end
    end
    return response
  end

  def post(url, body)
    while true
      @headers['Host'] = URI(url).host

      response = self.class.post(url, :body => body, :headers => @headers)
      update_cookie(response, url)

      if [301, 302].include? response.code 
        p "redirecting to " + response['location']
        url = response['location']
      else
        break
      end
    end

    return response
  end

  private
  def update_cookie(response, referer)
    # Obtain authentication cookie, merge with existing cookie
    @cookie.merge!(parse_cookies(response.headers['set-cookie']))
    # trường hợp trùng. ví dụ Set-Cookie: a=1; b=1; a=3 --> lấy 3 thôi, cái CGI.Cookie.parse nó ra a => [1,3] do đó phải lấy .last
    # tuy nhiên làm vậy (như cách hiện tại) lại ko support subcookie, ví dụ: AUTH=user=nghi&age=30 (AUTH => ['user=nghi', 'name=30'])
    #cookie_str = @cookie.select{|k,v| !['domain', 'path', 'expires', 'max-age', 'version'].include?(k.to_s.downcase) }.map{|k,v| "#{k}=#{v.join("&")}"}.join("; ")
    #cookie_str = @cookie.select{|k,v| !['domain', 'path', 'expires', 'max-age', 'version'].include?(k.to_s.downcase) }.map{|k,v| "#{k}=#{v.last}"}.join("; ")
    #ko dùng CGI::Cookie nữa, nó làm mất dấu +
    # ví dụ: x-wl-uid=1wBvpRznui0fSsb704qGff6zoLwoEUO+28SKrE13 => khi parse nó thành x-wl-uid=x-wl-uid=1wBvpRznui0fSsb704qGff6zoLwoEUO 28SKrE13
    @headers['Cookie'] = @cookie.map{|k,v| "#{k}=#{v}"}.join("; ")
    @headers['Referer'] = referer
  end

  def parse_cookies(cookie)
    return {} if cookie.nil?

    hash = {}
    cookie.scan(/[^\s]+=[^\s]+(?=;)/).delete_if{|i| i[/^(path=|domain=|version=|expires=|max-age=)/i] }.each do |i|
      key = i[/^[^=]+(?=\=)/] # lấy giá trị đầu tiên trước dấu bằng. Ví dụ:  "AUTH=user=1"[/^.*(?=\=)/] ==> AUTH
      val = i[/(?<=\=).*$/] # lấy phần còn lại. Ví dụ: "AUTH=user=1"[/(?<=\=).*$/] ==> user=1
      hash[key] = val
      # @todo: cần support thêm trong trường hợp AUTH=id=1&name=John thì phải tách thành 2 cặp key/val là id=>1 và name=>John, chứ ko dùng 1 cặp AUTH=>id=1&name=John (trường hợp subcookie)
    end

    return hash
  end
end

class Scrape
  MAX_PAGE = 99
  RETRY = 5
  DELAY = $options[:delay]
  DELAY_BEFORE_RETRY = 5
  IMAGE_PATH = '/tmp/images'
  SOURCE = 'AMAZON'

  def initialize
    @a = Mechanize.new
    @a.agent.http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    @a.load_proxies(Proxy.alive.to_array)
    @a.on(:hit) {|e|
      proxy = Proxy.find_by_ip(e.host)
      proxy.update_attributes(hit_count: e.hit_count)
    }

    @a.on(:failure) {|e|
      proxy = Proxy.find_by_ip(e.host)
      if proxy.failure_count - proxy.hit_count > 5
        log "#{e} --> kill"
        e.mark_dead!
        proxy.update_attributes(status: 'dead')
      else
        proxy.update_attributes(failure_count: e.failure_count)
      end
      
    }

    @a.on(:dead) {|e|
      proxy = Proxy.find_by_ip(e.host)
      proxy.mark_as_dead!
    }

    # @note Amazon thì ko được set cái này, đéo hiểu tại sao!!!
    # @a.user_agent_alias = 'Linux Mozilla'
  end

  def get2(item)
    log "Fetching #{item.url}"
    
    diff = ((Time.now - item.updated_at)/1.hours).round(2)
    if diff > Setting::get('ONLY_UPDATE_AFTER_X_HOURS', Float)
      log "diff = #{diff.to_s}"
    else
      log "diff = #{diff.to_s} (wait more)"
      return
    end

    ps = nil
    ps = @a.try do |scr|
      scr.get(item.get_url).parser
    end

    if ps.nil?
      log "Cannot get item #{url}"
      return
    end
    
    # key attributes
    item.url = item.get_url unless item.url
    item.title = ps.css('#productTitle').first.text.strip if ps.css('#productTitle').first
    item.title = ps.css('#btAsinTitle').first.text.strip unless item.title
    item.list_price = ps.css('#price_feature_div td').select{|e| e.text.downcase.include?('list price') }.first.next_element.text.strip.floatify if ps.css('#price_feature_div td').select{|e| e.text.downcase.include?('list price') }.first
    item.price = ps.css('#priceblock_ourprice').first.text.strip.floatify if ps.css('#priceblock_ourprice').first
    item.price = ps.css('#price_feature_div td').select{|e| ['Price:'].include?(e.text.strip) }.first.next_element.text.strip.floatify if item.price.blank? and ps.css('#price_feature_div td').select{|e| ['Price:'].include?(e.text.strip) }.first
    item.price = ps.css('#priceblock_saleprice').first.text.strip.floatify if item.price.blank? and ps.css('#priceblock_saleprice').first
    item.price = ps.css('#olp_feature_div span.a-color-price').first.text.strip.floatify if item.price.blank? and ps.css('#olp_feature_div span.a-color-price').first
    item.rank = ps.css('ul li span.zg_hrsr_rank').first.text[/[0-9,]+/].to_i if ps.css('ul li span.zg_hrsr_rank').first

    item.category = ps.css('#wayfinding-breadcrumbs_feature_div > ul > li').map{|li| li.text.strip }.join(" ")

    item.out_of_stock = !ps.css('#availability > span.a-color-price').empty?
    item.description = ps.css('.productDescriptionWrapper').first.inner_html.html2text if ps.css('.productDescriptionWrapper').first
    item.description = ps.css('#productDescription').first.inner_html.html2text if item.description.blank? and ps.css('#productDescription').first
    item.description = item.description.fix if item.description
    
    # image
    img_url = ps.css('#landingImage').first.attributes['data-old-hires'].value if ps.css('#landingImage').first
    img_url = ps.css('#landingImage').first.attributes['src'].value if img_url.blank?
    img_url = ps.css('#main-image').first.attributes['src'].value if img_url.blank?
    img_url = ps.css('body').inner_html[/(?<=colorImages).*/][/(?<=large...)http[^"]+/] if img_url.blank?
    img_url = ps.css('body').inner_html[/(?<=colorImages).*/][/(?<=main....)http[^"]+/] if img_url.blank?
    item.image_url = img_url
    item.status = Item::DONE
    
    qty_left, notes = scrape_qty_left(item)
    item.qty_left = qty_left
    item.notes = notes

    # save
    item.save!
    sleep DELAY
    return true
  end

  def scrape_qty_left(item)
    a = Mechanize.new do |agent|
      agent.pre_connect_hooks << lambda do |agent, request|
        headers = {
          'Accept' => 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
          'Accept-Encoding' => 'gzip,deflate,sdch',
          'Accept-Language' => 'en-US,en;q=0.8,vi;q=0.6',
          'Cache-Control' => 'max-age=0',
          'Connection' => 'keep-alive',
          #'Host' => 'www.amazon.com',
          #'Origin' => 'http://www.amazon.com',
          #'Referer' => 'http://www.amazon.com/gp/cart/view.html/ref=lh_cart_vc_btn',
          'User-Agent' => 'Mozilla/5.0 (Windows NT 6.3; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/43.0.2357.65 Safari/537.36',
          'X-AUI-View' => 'Desktop',
          'X-Requested-With' => 'XMLHttpRequest'
        }
        headers.each{|k,v| request[k] = v }
      end
    end

    # Detail page
    ps = a.get("#{item.amazonsite}/gp/product/" + item.number);0
    #query_string = JSON.parse(ps.body[/loadFeatures.*bbop-ms3-ajax-endpoint.html/m][/(?<=var data = ){.*}/m])
    #a.get('http://www.amazon.com/gp/product/du/bbop-ms3-ajax-endpoint.html?' + query_string.map{|k,v| "#{k}=#{v}"}.join('&'));0
    if item.us?
      a.get("#{item.amazonsite}/gp/bd/impress.html/ref=pba_sr_0")
    elsif item.uk?
      a.get("#{item.amazonsite}/gp/product/ajax-handlers/reftag.html/ref=psd_bb_i_#{item.number}")
    else
      return 0, 'Country not supported'
    end
      
    post_data = Hash[ps.parser.css('form#addToCart > input').map{|e| [e.attributes['name'].value, e.attributes['value'].value] }]
    # Post "Add to Cart"
    ps2 = a.post("#{item.amazonsite}/gp/product/handle-buy-box", post_data)
    ps3 = a.get("#{item.amazonsite}/gp/cart/view.html/ref=lh_cart_vc_btn")
    ps3.parser.css('.sc-list-body > div').count
    data_item_id = ps3.parser.css('div[data-asin="' + item.number + '"]').first.attributes['data-itemid'].value
    update_params = {
      'activePage' => ps3.parser.css('input[name="activePage"]').first.attributes['value'].value,
      'savedPage' => ps3.parser.css('input[name="savedPage"]').first.attributes['value'].value,
      'addressId' => ps3.parser.css('input[name="addressID"]').first.attributes['value'].value,
      'addressZip' => '',
      'hideAddonUpsell' => 1,
      'flcExpanded' => 0,
      "quantity.#{data_item_id}" => 999,#ps3.parser.css("input[name='quantity.#{data_item_id}']").first.attributes['value'].value,
      'pageAction' => 'update-quantity',
      "submit.update-quantity.#{data_item_id}" => ps3.parser.css("input[name='submit.update-quantity.#{data_item_id}']").first.attributes['value'].value,
      'actionItemID' => data_item_id,
      'asin' => item.number
    }

    ps4 = a.post("#{item.amazonsite}/gp/cart/ajax-update.html", update_params)
    
    notes = nil
    if ps4.body[/999 items/]
      qty_left = 999
    elsif ps4.body[/(?<=This seller has a limit of )[0-9,]*/]
      qty_left = ps4.body[/(?<=This seller has a limit of )[0-9,]*/]
      notes = 'This seller has a limit of ' + qty_left.to_s + " per customer"
    elsif ps4.body[/[0-9,]*(?= of these available)/]
      qty_left = ps4.body[/[0-9,]*(?= of these available)/].strip
    end

    return qty_left, notes
  end

  private 
  def log(msg)
    # p msg
    $logger.info(msg)
  end
end


#--------------------------------------------
# RUN
#--------------------------------------------

MAX = 10

# trap Ctrl-C
trap("SIGINT") { throw :ctrl_c }

catch :ctrl_c do
  while true
    collection = Item.in_progress

    if collection.empty?
      # 1st priority NEW item
      queue = Item._new.order('updated_at ASC').limit(MAX)
      
      # 2nd priority DONE item
      queue = Item.done.order('updated_at ASC').limit(MAX) if queue.empty?

      queue.update_all(status: Item::IN_PROGRESS)
    else
      # Actually run the queue
      e = Scrape.new
      collection.each do |i|
        e.get2(i)
      end
    end

    sleep 3
  end
end

# DATABASE_URL=postgres://postgres:postgres@localhost:5432/amazon150517 ruby lib/amazon_scraper.rb