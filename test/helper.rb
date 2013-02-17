require 'bundler/setup'
require 'minitest/unit'
require 'tempfile'
require 'simplecov'
require 'furnish'
require 'furnish/provisioners/dummy'

Dummy = Furnish::Provisioner::Dummy unless defined? Dummy

class StartFailDummy < Dummy
  def startup(*args)
    super
    false
  end
end

class StopFailDummy < Dummy
  def shutdown
    super
    false
  end
end

SimpleCov.start if ENV["COVERAGE"]

module Furnish
  class TestCase < MiniTest::Unit::TestCase

    def reinit
      @tempfiles ||= []
      file = Tempfile.new('furnish_db')
      @tempfiles.push(file)
      Furnish.init(file.path)
      return file
    end

    def setup
      reinit
    end

    def teardown
      Furnish.shutdown
      @tempfiles.each do |file|
        file.unlink
      end
    end
  end

  class SchedulerTestCase < TestCase
    attr_reader :sched

    def setup
      super
      Furnish.logger = Furnish::Logger.new(Tempfile.new("furnish_log"), 3)
      @sched = Furnish::Scheduler.new
    end

    def teardown
      Furnish.logger.close
      super
    end
  end
end

require 'minitest/autorun'
