class Proxy < ActiveRecord::Base
  ALIVE = 'alive'
  DEAD = 'dead'

  # attr_accessible :ip, :port, :username, :password, :status, :failure_count, :hit_count
  
  scope :alive, -> { where(status: ALIVE) }
  scope :dead, -> { where(status: DEAD) }

  validates :ip, format: { with: /\A(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})\Z/, message: "invalid IP address" }, uniqueness: true
  validates :port, numericality: { only_integer: true }

  def mark_as_dead!
    self.status = 'dead'
    self.save!
  end

  def self.to_array
    self.all.map{|e| [e.ip, e.port, e.username, e.password]}
  end

  def self.import(text)
    done = []
    failed = []
    text.split(/[\r\n\s\t]+/).each do |line|
      ip, port, username, password = line.strip.split(/[:,;\s]+/)
      proxy = self.new(ip: ip, port: port, username: username, password: password, status: ALIVE)
      if proxy.save
        done << proxy.ip
      else
        failed << proxy.ip
      end
    end

    return [done, failed]
  end

end
