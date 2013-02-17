require 'helper'

class TestSchedulerSerial < Furnish::RunningSchedulerTestCase
  def setup
    super
    sched.serial = true
  end

  def test_threading_constructs
    assert(sched.schedule_provision('blarg', Dummy.new))
    sched.run
    assert_nil(sched.wait_for('blarg'))
    sched.stop # does not explode
  end

  def test_provision_failures
    dummy = StartFailDummy.new
    assert(sched.schedule_provision('blarg', dummy))
    assert_raises(RuntimeError, "Could not provision blarg with provisioner StartFailDummy") { sched.run }
    sched.deprovision_group('blarg')

    # tests scheduler crashes not keeping the scheduler from being restarted
    assert(sched.schedule_provision('blarg', Dummy.new))
    sched.run
    assert_includes(sched.solved, "blarg")
    sched.teardown
    refute_includes(sched.solved, "blarg")

    dummy = StopFailDummy.new
    assert(sched.schedule_provision('blarg', StopFailDummy.new))
    sched.run
    assert_includes(sched.solved, "blarg")
    assert_raises(RuntimeError) { sched.teardown }
    assert_includes(sched.solved, "blarg")
    sched.force_deprovision = true
    sched.teardown
    refute_includes(sched.solved, "blarg")
  end
end
