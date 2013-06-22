require 'helper'
require 'mt_cases'

class TestSchedulerSerial < Furnish::RestartingSchedulerTest
  def setup
    super
    sched.serial = true
  end

  def test_threading_constructs
    assert(sched.schedule_provision('blarg', Dummy.new))
    sched.run
    refute(sched.running?)
    assert_nil(sched.wait_for('blarg'))
    sched.stop # does not explode
  end
end
