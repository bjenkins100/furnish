require 'palsy'

module Furnish
  def self.init(database_file)
    Palsy.change_db(database_file)
  end

  def self.shutdown
    Palsy.instance.close
  end
end

require 'furnish/version'
require 'furnish/scheduler'
