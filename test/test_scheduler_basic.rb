require 'helper'

class TestSchedulerBasic < Furnish::SchedulerTestCase
  def test_schedule_provision
    assert(sched.schedule_provision('blarg', [Dummy.new]), 'we can schedule')
    assert_includes(sched.vm.waiters.keys, 'blarg', 'exists in the waiters')
    assert_includes(sched.vm.groups.keys, 'blarg', 'exists in the vm group set')
    assert_equal(1, sched.vm.groups['blarg'].count, 'one item array')
    assert_kind_of(Furnish::Provisioner::Dummy, sched.vm.groups['blarg'].first, 'first object is our dummy object')
    assert_equal('blarg', sched.vm.groups['blarg'].first.furnish_group_name, 'name is set properly')
    assert_nil(sched.schedule_provision('blarg', [Dummy.new]), 'does not schedule twice')

    assert(sched.schedule_provision('blarg2', Dummy.new), 'scheduling does not need an array')
    assert_includes(sched.vm.waiters.keys, 'blarg2', 'exists in the waiters')
    assert_includes(sched.vm.groups.keys, 'blarg2', 'exists in the vm group set')
    assert_kind_of(Furnish::ProvisionerGroup, sched.vm.groups['blarg2'], 'boxes our single item')
    assert_kind_of(Furnish::Provisioner::Dummy, sched.vm.groups['blarg2'].first, 'first object is our dummy object')
    assert_equal('blarg2', sched.vm.groups['blarg2'].first.furnish_group_name, 'name is set properly')

    assert_raises(
      RuntimeError,
      "One of your dependencies for blarg3 has not been pre-declared. Cannot continue"
    ) do
      sched.schedule_provision('blarg3', Dummy.new, %w[frobnik])
    end

    assert(sched.schedule_provision('blarg4', Dummy.new, %w[blarg2]), 'scheduled with a dependency')
    assert_includes(sched.vm.waiters.keys, 'blarg4', 'included in waiters list')
    assert_includes(sched.vm.dependencies['blarg4'], 'blarg2', 'dependencies are tracked for provision')
  end

  def test_protocol
    # NOTE these classes are in test/dummy_classes.rb
    assert(sched.schedule_provision('blarg', [YieldsIntegerBarDummy.new, AcceptsIntegerBarDummy.new]))
    assert(sched.schedule_provision('blarg1', [YieldsIntegerBarDummy.new, RequiresBarDummy.new]))
    assert(sched.schedule_provision('blarg2', [YieldsStringBarDummy.new, AcceptsStringBarDummy.new]))
    assert_raises(ArgumentError) { sched.schedule_provision('blarg3', [YieldsStringBarDummy.new, RequiresBarDummy.new]) }
    assert_raises(ArgumentError) { sched.schedule_provision('blarg4', [YieldsStringBarDummy.new, AcceptsIntegerBarDummy.new]) }
    assert_raises(ArgumentError) { sched.schedule_provision('blarg5', [YieldsFooDummy.new, AcceptsIntegerBarDummy.new]) }
    assert_raises(ArgumentError) { sched.schedule_provision('blarg6', [YieldsFooDummy.new, RequiresBarDummy.new]) }
    assert_raises(ArgumentError) { sched.schedule_provision('blarg7', [YieldsIntegerBarDummy.new, AcceptsFooDummy.new]) }
    assert_raises(ArgumentError) { sched.schedule_provision('blarg8', [YieldsStringBarDummy.new, AcceptsFooDummy.new]) }
    assert_raises(ArgumentError) { sched.schedule_provision('blarg9', [YieldsIntegerBarDummy.new, RequiresBarAcceptsFooDummy.new]) }
    assert(sched.schedule_provision('blarg10', [YieldsFooBarDummy.new, RequiresBarAcceptsFooDummy.new]))
    assert(sched.schedule_provision('blarg11', [YieldsFooBarDummy.new, AcceptsFooDummy.new]))
    assert(sched.schedule_provision('blarg12', [YieldsFooBarDummy.new, AcceptsIntegerBarDummy.new]))
    assert(sched.schedule_provision('blarg13', [YieldsFooDummy.new, AcceptsFooDummy.new]))
    assert(sched.schedule_provision('blarg14', [YieldsFooBarDummy.new, RequiresBarDummy.new]))

    assert(sched.schedule_provision('blarg-shutdown', [ShutdownAcceptsIntegerBarDummy.new, ShutdownYieldsIntegerBarDummy.new]))
    assert(sched.schedule_provision('blarg1-shutdown', [ShutdownRequiresBarDummy.new, ShutdownYieldsIntegerBarDummy.new]))
    assert(sched.schedule_provision('blarg2-shutdown', [ShutdownAcceptsStringBarDummy.new, ShutdownYieldsStringBarDummy.new]))
    assert_raises(ArgumentError) { sched.schedule_provision('blarg3-shutdown', [ShutdownRequiresBarDummy.new, ShutdownYieldsStringBarDummy.new] ) }
    assert_raises(ArgumentError) { sched.schedule_provision('blarg4-shutdown', [ShutdownAcceptsIntegerBarDummy.new, ShutdownYieldsStringBarDummy.new]) }
    assert_raises(ArgumentError) { sched.schedule_provision('blarg5-shutdown', [ShutdownAcceptsIntegerBarDummy.new, ShutdownYieldsFooDummy.new]) }
    assert_raises(ArgumentError) { sched.schedule_provision('blarg6-shutdown', [ShutdownRequiresBarDummy.new, ShutdownYieldsFooDummy.new]) }
    assert_raises(ArgumentError) { sched.schedule_provision('blarg7-shutdown', [ShutdownAcceptsFooDummy.new, ShutdownYieldsIntegerBarDummy.new]) }
    assert_raises(ArgumentError) { sched.schedule_provision('blarg8-shutdown', [ShutdownAcceptsFooDummy.new, ShutdownYieldsStringBarDummy.new]) }
    assert_raises(ArgumentError) { sched.schedule_provision('blarg9-shutdown', [ShutdownRequiresBarAcceptsFooDummy.new, ShutdownYieldsIntegerBarDummy.new]) }
    assert(sched.schedule_provision('blarg10-shutdown', [ShutdownRequiresBarAcceptsFooDummy.new, ShutdownYieldsFooBarDummy.new]))
    assert(sched.schedule_provision('blarg11-shutdown', [ShutdownAcceptsFooDummy.new, ShutdownYieldsFooBarDummy.new]))
    assert(sched.schedule_provision('blarg12-shutdown', [ShutdownAcceptsIntegerBarDummy.new, ShutdownYieldsFooBarDummy.new]))
    assert(sched.schedule_provision('blarg13-shutdown', [ShutdownAcceptsFooDummy.new, ShutdownYieldsFooDummy.new]))
    assert(sched.schedule_provision('blarg14-shutdown', [ShutdownRequiresBarDummy.new, ShutdownYieldsFooBarDummy.new]))
  end
end
