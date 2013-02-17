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

    def setup
      @tempfiles ||= []
      file = Tempfile.new('furnish_db')
      @tempfiles.push(file)
      Furnish.init(file.path)
      return file
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

    def assert_started(name)
      assert_includes(sched.solved, name, 'scheduler thinks it solved it')
      assert(sched.vm_groups[name].first.store[ [name, "startup"].join("-") ], "dummy provisioner for #{name} recorded the startup run")
      refute(sched.vm_groups[name].first.store[ [name, "shutdown"].join("-") ], "dummy provisioner for #{name} has not recorded the shutdown run")
    end

    def assert_shutdown(name, provisioner)
      refute_includes(sched.solved, name, 'scheduler thinks it solved it')
      assert(provisioner.store[ [name, "shutdown"].join("-") ], "dummy provisioner for #{name} recorded the shutdown run")
    end

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
