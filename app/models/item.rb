require 'sql_helper'

class Item < ActiveRecord::Base
  extend SqlHelper

  NEW = 'new'
  IN_PROGRESS = 'in_progress'
  DONE = 'done'
  FAILED = 'failed'
  
  scope :failed, -> { where(status: FAILED) }
  scope :in_progress, -> { where(status: IN_PROGRESS) }
  scope :done, -> { where(status: DONE) }
  scope :_new, -> { where(status: NEW) }

  def self.import(path)
    data = []
    puts "---------------------------------------"
    existing_numbers = Item.pluck(:number)
    puts existing_numbers  

    CSV.foreach(path, headers: true) {|line| 
      puts "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
      h_data = line.to_h
      p h_data
      p existing_numbers.include?(h_data['number'])
      data << h_data unless existing_numbers.include?(h_data['number']) 
    }

    self.execute_db_update!(data)
  end
end
