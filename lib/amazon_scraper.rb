raise "DATABASE_URL not set" unless ENV['DATABASE_URL']

require 'optparse'
require 'rubygems'
require 'active_record'
require 'mechanize'
require 'zlib'
require 'timeout'

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

$task = Task.find($options[:task]) if $options[:task]

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

class Scrape
  SITE = 'http://www.amazon.com/'
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

  def run(url)
    last_page = Item.where(category_url: url).maximum(:page) || 1
    log "start from #{last_page}"
    last_page.upto(MAX_PAGE) do |page|
      page_url = url.gsub(/(?<=page=)[0-9]+/, page.to_s)
      page_url = "#{page_url}&page=#{page}" unless page_url.include?('page=')

      log "Page URL: #{page_url}"
      
      resp = nil

      # RETRY.times {
      #   begin
      #     resp = @a.get(page_url)
      #     break
      #   rescue Exception => ex
      #     resp = nil
      #     log "Error fetching #{page_url}"
      #     sleep DELAY_BEFORE_RETRY
      #   end
      # }

      resp = @a.try do |scr|
        scr.get(page_url)
      end

      $task.update_attributes(progress: "Scraping...") if $task

      if resp.blank?
        log "Cannot get page #{page_url}"
        next
      end
      
      ps = resp.parser

      results_count = ps.css('#s-result-count').first.text[/(?<=of\s)[0-9,]+/] if ps.css('#s-result-count').first
      log "Total " + results_count.to_s
      
      # only scrape PRIME items
      count_all = ps.css('#atfResults > ul > li a > h2:nth-child(1)').count
      item_urls = ps.css('#atfResults > ul > li a > h2:nth-child(1)').select{|h2| !h2.parent.parent.parent.parent.css('i.a-icon-prime').empty? }.map{|h2| h2.parent.attributes['href'].value }
      
      log "Item Count #{item_urls.count}"

      item_urls.each do |item_url|
        get(item_url, {page_url: page_url, category_url: url, page: page, results_count: results_count} )
      end

      break if count_all == 0
    end
  end

  def get(url, meta = {})
    log "Fetching #{url}"

    asin = url[/(?<=dp.)[A-Z0-9]+/]
    
    if asin.blank?
      log "Invalid ASIN from #{url.to_s}, " + meta.to_s
      return
    end

    ps = nil

    ps = @a.try do |scr|
      scr.get(url).parser
    end
    
    if ps.nil?
      log "Cannot get item #{url}"
      return
    end

    # initiate
    item = Item.new
    
    # key attributes
    item.url = url
    item.number = asin
    item.title = ps.css('#productTitle').first.text.strip if ps.css('#productTitle').first
    item.title = ps.css('#btAsinTitle').first.text.strip unless item.title
    item.list_price = ps.css('#price_feature_div td').select{|e| e.text.downcase.include?('list price') }.first.next_element.text.strip.floatify if ps.css('#price_feature_div td').select{|e| e.text.downcase.include?('list price') }.first
    item.price = ps.css('#priceblock_ourprice').first.text.strip.floatify if ps.css('#priceblock_ourprice').first
    item.price = ps.css('#price_feature_div td').select{|e| ['Price:'].include?(e.text.strip) }.first.next_element.text.strip.floatify if item.price.blank? and ps.css('#price_feature_div td').select{|e| ['Price:'].include?(e.text.strip) }.first
    item.price = ps.css('#priceblock_saleprice').first.text.strip.floatify if item.price.blank? and ps.css('#priceblock_saleprice').first
    item.price = ps.css('#olp_feature_div span.a-color-price').first.text.strip.floatify if item.price.blank? and ps.css('#olp_feature_div span.a-color-price').first

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

    # save
    item.save!
    $task.update_attributes(status: Task::RUNNING, progress: "Last item scraped: #{item.number}") if $task
    log "----------------- DONE -------------------"
    sleep DELAY
    return true
  end

  private 
  def log(msg)
    # p msg
    $logger.info(msg)
  end
end

# trap Ctrl-C
trap("SIGINT") { throw :ctrl_c }

catch :ctrl_c do
  begin
    $task.update_attributes(status: Task::RUNNING, progress: 'Starting...') if $task
    e = Scrape.new
    if $options[:url]
      e.run($options[:url])
    elsif $options[:item]
      e.get($options[:item])
    end
    $task.update_attributes(status: Task::DONE, progress: '100%') if $task
  rescue Exception => ex
    $logger.info "Something went wrong, please check your proxies\r\n#{ex.message}\r\nBacktrace:\r\n" + ex.backtrace.join("\r\n")
    $task.update_attributes(status: Task::FAILED, progress: "Something went wrong, please check your proxies\r\n#{ex.message}\r\nBacktrace:\r\n" + ex.backtrace.join("\r\n")) if $task
  end
end

