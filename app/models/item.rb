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
    CSV.foreach(path, headers: true) {|line| data << line.to_h}
    self.execute_db_update!(data)
  end
end
