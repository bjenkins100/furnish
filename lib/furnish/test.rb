require 'minitest/unit'
require 'tempfile'
require 'furnish'

module Furnish
  #
  # Furnish::TestCase is a test harness for testing things with furnish, like
  # provisioner libraries. It is intended to be consumed by other libraries.
  #
  # There are few others, such as SchedulerTestCase and
  # RunningSchedulerTestCase which are tuned to specific scenarios, but inherit
  # from this class.
  #
  # The basic case initializes furnish and the logger in a safe way in setup,
  # and cleans up in teardown.
  #
  # If FURNISH_DEBUG is present in the environment, the output of the furnish
  # log will be presented to the standard error. Otherwise, it is sent a log
  # file.
  #
  class TestCase < MiniTest::Unit::TestCase
    def setup # :nodoc:
      unless Furnish.initialized?
        @tempfiles ||= []
        file = Tempfile.new('furnish_db')
        @tempfiles.push(file)
        if ENV["FURNISH_DEBUG"]
          Furnish.logger = Furnish::Logger.new($stderr, 3)
        else
          logfile = Tempfile.new('furnish_log')
          @tempfiles.push(logfile)
          Furnish.logger = Furnish::Logger.new(logfile, 3)
        end
        Furnish.init(file.path)
      end

      return file
    end

    def teardown(shutdown=true) # :nodoc:
      unless ENV["FURNISH_DEBUG"]
        Furnish.logger.close
      end

      if shutdown
        Furnish.shutdown
        @tempfiles.each do |file|
          file.unlink
        end
      end
    end
  end

  #
  # SchedulerTestCase inherits from Furnish::TestCase and configures a threaded
  # scheduler, but does not attempt to start it. It's intended to be a
  # primitive for cases where you might create a number of schedulers.
  #
  # If the scheduler throws an exception for any reason, the test suite will
  # abort.
  #
  # RunningSchedulerTestCase deals with managing a running scheduler for you.
  #
  class SchedulerTestCase < TestCase
    ##
    # Furnish::Scheduler object.
    attr_reader :sched

    def setup # :nodoc:
      super
      @sched ||= Furnish::Scheduler.new
      @monitor = Thread.new { loop { @sched.running?; sleep 1 } }
      @monitor.abort_on_exception = true
    end

    def teardown(shutdown=true) # :nodoc:
      @monitor.kill rescue nil
      super(shutdown)
    end

    ##
    #
    # Assert the named group is solved, as far as the scheduler's concerned.
    #
    def assert_solved(name)
      assert_includes(sched.vm.solved, name, "#{name} is solved in the scheduler")
    end

    ##
    #
    # Refute the named group is solved, as far as the scheduler's concerned.
    #
    def refute_solved(name)
      refute_includes(sched.vm.solved, name, "#{name} is solved in the scheduler")
    end
  end

  ##
  #
  # Inherits from SchedulerTestCase and manages a running scheduler in
  # conjunction with all the other features.
  #
  class RunningSchedulerTestCase < SchedulerTestCase
    def setup # :nodoc:
      super
      @sched.run
    end

    def teardown # :nodoc:
      @sched.stop
      sleep 0.3 while @sched.running?
      super
    end
  end
end
