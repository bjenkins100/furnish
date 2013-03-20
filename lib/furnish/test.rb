require 'minitest/unit'
require 'tempfile'
require 'furnish'

module Furnish
  class TestCase < MiniTest::Unit::TestCase
    def setup
      @tempfiles ||= []
      file = Tempfile.new('furnish_db')
      @tempfiles.push(file)
      logfile = Tempfile.new('furnish_log')
      @tempfiles.push(logfile)
      Furnish.logger = Furnish::Logger.new(logfile, 3)
      Furnish.init(file.path)
      return file
    end

    def teardown
      Furnish.logger.close
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
      @sched = Furnish::Scheduler.new
      @monitor = Thread.new { loop { @sched.running?; sleep 1 } }
      @monitor.abort_on_exception = true
    end

    def teardown
      @monitor.kill rescue nil
      super
    end

    def assert_solved(name)
      assert_includes(sched.vm.solved, name, "#{name} is solved in the scheduler")
    end

    def refute_solved(name)
      refute_includes(sched.vm.solved, name, "#{name} is solved in the scheduler")
    end
  end

  class RunningSchedulerTestCase < SchedulerTestCase
    def setup
      super
      @sched.run
    end

    def teardown
      @sched.stop
      sleep 0.3 while @sched.running?
      super
    end
  end
end
