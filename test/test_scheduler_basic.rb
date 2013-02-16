require 'helper'
require 'furnish/provisioners/dummy'

Dummy = Furnish::Provisioner::Dummy unless defined? Dummy

class TestSchedulerBasic < Furnish::TestCase
  def setup
    super
    Furnish.logger(Tempfile.new("furnish_log"), 3)
  end

  def teardown
    Furnish.logger.close
    super
  end

  def test_schedule_provision
    sched = Furnish::Scheduler.new

    assert(sched.schedule_provision('blarg', [Dummy.new]), 'we can schedule')
    assert_includes(sched.waiters.keys, 'blarg', 'exists in the waiters')
    assert_includes(sched.vm_groups.keys, 'blarg', 'exists in the vm group set')
    assert_equal(1, sched.vm_groups['blarg'].count, 'one item array')
    assert_kind_of(Furnish::Provisioner::Dummy, sched.vm_groups['blarg'].first, 'first object is our dummy object')
    assert_equal('blarg', sched.vm_groups['blarg'].first.name, 'name is set properly')
    assert_nil(sched.schedule_provision('blarg', [Dummy.new]), 'does not schedule twice')

    assert(sched.schedule_provision('blarg2', Dummy.new), 'scheduling does not need an array')
    assert_includes(sched.waiters.keys, 'blarg2', 'exists in the waiters')
    assert_includes(sched.vm_groups.keys, 'blarg2', 'exists in the vm group set')
    assert_kind_of(Array, sched.vm_groups['blarg2'], 'boxes our single item')
    assert_kind_of(Furnish::Provisioner::Dummy, sched.vm_groups['blarg2'].first, 'first object is our dummy object')
    assert_equal('blarg2', sched.vm_groups['blarg2'].first.name, 'name is set properly')

    assert_raises(
      RuntimeError,
      "One of your dependencies for blarg3 has not been pre-declared. Cannot continue"
    ) do
      sched.schedule_provision('blarg3', Dummy.new, %w[frobnik])
    end

    assert(sched.schedule_provision('blarg4', Dummy.new, %w[blarg2]), 'scheduled with a dependency')
    assert_includes(sched.waiters.keys, 'blarg4', 'included in waiters list')
    assert_includes(sched.vm_dependencies['blarg4'], 'blarg2', 'dependencies are tracked for provision')
  end
end
