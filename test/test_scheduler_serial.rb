require 'helper'

class TestSchedulerSerial < Furnish::SchedulerTestCase
  def setup
    super
    @sched = Furnish::Scheduler.new
    @sched.serial = true
  end

  def assert_started(name)
    assert_includes(@sched.solved, name, 'scheduler thinks it solved it')
    assert(@sched.vm_groups[name].first.store[ [name, "startup"].join("-") ], "dummy provisioner for #{name} recorded the startup run")
    refute(@sched.vm_groups[name].first.store[ [name, "shutdown"].join("-") ], "dummy provisioner for #{name} has not recorded the shutdown run")
  end

  def assert_shutdown(name, provisioner)
    refute_includes(@sched.solved, name, 'scheduler thinks it solved it')
    assert(provisioner.store[ [name, "shutdown"].join("-") ], "dummy provisioner for #{name} recorded the shutdown run")
  end

  def test_provision_cycle
    machine_names = %w[blarg blarg2 blarg3]

    machine_names.each do |name|
      assert(@sched.schedule_provision(name, Dummy.new))
    end

    @sched.run

    machine_names.each do |name|
      assert_started(name)
    end

    machine_provs = machine_names.map { |n| @sched.vm_groups[n].first }

    @sched.teardown

    machine_names.each_with_index do |name, i|
      assert_shutdown(name, machine_provs[i])
    end
  end

  def test_dependent_provision
    # since we can't reliably predict linear order, we just paritition it by
    # how the dependency resolver should sort things out. This isn't perfect by
    # any means and largely only works because we're serial here, but allows us
    # to check the dependency resolver.
    machine_order = {
      "blarg1" => %w[blarg2 blarg3],
      "blarg2" => %w[blarg4],
      "blarg3" => %w[blarg4],
      "blarg4" => [],
      "blarg5" => []
    }

    assert(@sched.schedule_provision('blarg1', Dummy.new))
    assert(@sched.schedule_provision('blarg2', Dummy.new, %w[blarg1]))
    assert(@sched.schedule_provision('blarg3', Dummy.new, %w[blarg1]))
    assert(@sched.schedule_provision('blarg4', Dummy.new, %w[blarg2 blarg3]))
    assert(@sched.schedule_provision('blarg5', Dummy.new))

    @sched.run

    1.upto(5) { |x| assert_started("blarg#{x}") }

    order = Dummy.new.order
    possible_next = Set[*%w[blarg1 blarg5]]

    while machine = order.shift
      assert_includes(possible_next, machine, "machine was matched in possible nexts")
      machine_order[machine].each do |nexts|
        possible_next.add(nexts)
      end

      possible_next.delete(machine)
    end

    machine_provs = (1..5).map { |n| @sched.vm_groups["blarg#{n}"].first }

    @sched.teardown

    1.upto(5) { |x| assert_shutdown("blarg#{x}", machine_provs[x-1]) }
  end
end
