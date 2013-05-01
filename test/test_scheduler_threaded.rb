require 'helper'
require 'mt_cases'

# NOTE the dummy classes in this file are defined in test/dummy_classes.rb
class TestSchedulerThreaded < Furnish::RestartingSchedulerTestCase
  def setup
    super
    sched.serial = false
  end

  def test_running
    assert(sched.schedule_provision('blarg', SleepyDummy.new))
    sched.run
    assert(sched.running?, 'running after provision')
    sched.teardown
    refute(sched.running?, 'not running after teardown')

    # we have a monitor that's waiting for timeouts in the test suite to abort
    # it if the scheduler crashes.
    #
    # this actually tests that functionality, so kill the monitor prematurely.
    #
    assert(sched.schedule_provision('blarg', SleepyFailingDummy.new))
    sched.run
    assert(sched.running?, 'running after provision')
    sleep 4
    assert(sched.running?, 'still running after failure')
    assert_kind_of(RuntimeError, sched.needs_recovery['blarg'])
    assert_equal("Could not provision blarg[SleepyFailingDummy]", sched.needs_recovery['blarg'].message)
    sched.teardown
    refute(sched.running?, 'not running after teardown')
  end
end
