require 'helper'

class TestSchedulerThreaded < Furnish::RunningSchedulerTestCase
  def setup
    super
    sched.serial = false
  end
end
