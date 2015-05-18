require 'sql_helper'

class Item < ActiveRecord::Base
  extend SqlHelper

  def self.import(path)
    data = []
    CSV.foreach(path, headers: true) {|line| data << line.to_h}
    self.execute_db_update!(data)
  end
end
