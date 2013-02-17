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
end
