require 'sql_helper'

class Item < ActiveRecord::Base
  extend SqlHelper

  has_many :item_statistics

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
  
  def get_statistics(from = nil, to = nil)
    scope = self.item_statistics
    scope = scope.where('created_at::date >= :from', from: Date.parse(from)) if from
    scope = scope.where('created_at::date <= :to', to: Date.parse(to)) if to
    return scope.all
  end

  def self.import(path)
    data = []
    existing_numbers = Item.pluck(:number)
    puts existing_numbers  

    CSV.foreach(path, headers: true) {|line| 
      h_data = line.to_h
      data << h_data unless existing_numbers.include?(h_data['number']) 
    }

    self.execute_db_update!(data)
  end
end
