require 'palsy'

module Furnish
  def self.init(database_file)
    Palsy.change_db(database_file)
  end
end

require 'furnish/version'
require 'furnish/scheduler'
