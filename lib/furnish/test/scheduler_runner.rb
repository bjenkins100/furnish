module Minitest
  class << self
    attr_accessor :keep_scheduler

    remove_method :__run

    def __run(reporter, options)
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
