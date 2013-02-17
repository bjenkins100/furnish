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
end
