#
# Monkey Patches for Minitest for Furnish::Test
#
module Minitest
  class << self
    #
    # If this is set, the scheduler will be kept running between test methods,
    # so that it can be re-used. This can be used to save some time in
    # situaitons where a long-running provision will be used in all methods in
    # a suite.
    #
    attr_accessor :keep_scheduler

    remove_method :__run

    def __run(reporter, options) # :nodoc:
      at_exit do
        if Furnish.initialized?
          $sched.force_deprovision = true
          #$sched.teardown
          #Furnish.shutdown
          FileUtils.rm_f('test.db')
        end
      end

      Minitest::Runnable.runnables.each do |suite|
        begin
          if keep_scheduler
            require 'fileutils'
            Furnish.init('test.db') unless Furnish.initialized?

            if ENV["FURNISH_DEBUG"]
              Furnish.logger = Furnish::Logger.new($stderr, 3)
            end

            $sched ||= Furnish::Scheduler.new
            $sched.run
          end

          if suite.respond_to?(:before_suite)
            suite.before_suite
          end

          suite.run(reporter, options)
        ensure
          if suite.respond_to?(:after_suite)
            suite.after_suite
          end
        end
      end
    end
  end
end
