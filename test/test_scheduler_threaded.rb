require 'helper'

class SleepyDummy < Dummy
  def startup(*args)
    sleep 1
    super
  end
end

class SleepyFailingDummy < SleepyDummy
  def startup(*args)
    super
    return false
  end
end

class TestSchedulerThreaded < Furnish::RunningSchedulerTestCase
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

    assert(sched.schedule_provision('blarg', SleepyFailingDummy.new))
    sched.run
    assert(sched.running?, 'running after provision')
    sleep 3
    assert_raises(RuntimeError, "Could not provision blarg with provisioner SleepyFailingDummy") { sched.running? }
    sched.teardown
    refute(sched.running?, 'not running after teardown')
  end
end
