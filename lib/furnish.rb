require 'palsy'
require 'furnish/version'
require 'furnish/logger'
require 'furnish/scheduler'

#
# Furnish is a scheduling system. Check out the README for basic usage
# instructions.
#
# You may also wish to read the Furnish::Scheduler, Furnish::Logger, and
# Furnish::ProvisionerGroup documentation to learn more about it.
#
module Furnish
  #
  # Initialize Furnish. The path given is to a SQLite 3 database file that it
  # will create for you.
  #
  def self.init(database_file)
    Palsy.change_db(database_file)
  end

  #
  # Access the logger (Furnish::Logger) or override it if it does not already
  # exist. In the latter case, Furnish#logger= might be more reliable.
  #
  # The default logger is pointed at standard error and has a debug level of 0.
  #
  def self.logger(io=$stderr, debug_level=0)
    return @logger if @logger
    @logger ||= Furnish::Logger.new(io, debug_level)
  end

  #
  # Set the logger. This is expected to have an interface akin to
  # Furnish::Logger, it's not the same as ruby's Logger.
  #
  def self.logger=(logger)
    @logger = logger
  end

  #
  # Shutdown Furnish by closing its state file. Furnish::Scheduler objects and
  # the threads it spawns must be stopped already, otherwise you're going to
  # have a bad day.
  #
  def self.shutdown
    Palsy.instance.close
  end
end
