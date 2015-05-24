require 'sql_helper'

class Item < ActiveRecord::Base
  extend SqlHelper

  has_many :item_statistics, dependent: :destroy

  NEW = 'new'
  IN_PROGRESS = 'in_progress'
  DONE = 'done'
  FAILED = 'failed'
  INVALID = 'invalid'
  
  scope :failed, -> { where(status: FAILED) }
  scope :in_progress, -> { where(status: IN_PROGRESS) }
  scope :done, -> { where(status: DONE) }
  scope :_new, -> { where(status: NEW) }
  scope :invalid, -> { where(status: INVALID) }

  validates :country, presence: true
  validates :number, presence: true
  validates :number, format: { with: /\A[a-zA-Z0-9]{10}\z/,
    message: "invalid ASIN" }
  
  def get_statistics(from = nil, to = nil)
    scope = self.item_statistics
    scope = scope.where('created_at::date >= :from', from: Date.parse(from)) unless from.blank?
    scope = scope.where('created_at::date <= :to', to: Date.parse(to)) unless to.blank?
    return scope.order('created_at ASC').all
  end

  def display_name
    self.number
  end

  def self.import(path)
    data = []
    existing_numbers = Item.pluck(:number)
    puts existing_numbers  
    
    # todo: better validation required
    CSV.foreach(path, headers: true) {|line| 
      h_data = line.to_h
      next if h_data['number'].blank?
      next if h_data['country'].blank?
      next unless h_data['number'][/[a-z0-9]{10}/i]  # not an asin
      next if existing_numbers.include?(h_data['number']) 

      data << h_data
    }

    self.execute_db_update!(data)
  end
end
