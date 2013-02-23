require 'palsy'
require 'furnish/logger'
require 'furnish/version'
require 'furnish/scheduler'

module Furnish
  def self.init(database_file)
    Palsy.change_db(database_file)
  end

  def self.logger(io=$stderr, debug_level=0)
    return @logger if @logger
    @logger ||= Furnish::Logger.new(io, debug_level)
  end

  def self.logger=(logger)
    @logger = logger
  end

  def self.shutdown
    Palsy.instance.close
  end
end
