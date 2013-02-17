require 'furnish/provisioners/dummy'

Dummy = Furnish::Provisioner::Dummy unless defined? Dummy

class StartFailDummy < Dummy
  def startup(*args)
    super
    false
  end
end

class StopFailDummy < Dummy
  def shutdown
    super
    false
  end
end

module Furnish
  class TestCase < MiniTest::Unit::TestCase
    def setup
      @tempfiles ||= []
      file = Tempfile.new('furnish_db')
      @tempfiles.push(file)
      Furnish.init(file.path)
      return file
    end

    def teardown
      Furnish.shutdown
      @tempfiles.each do |file|
        file.unlink
      end
    end
  end

  class SchedulerTestCase < TestCase
    attr_reader :sched

    def setup
      super
      Furnish.logger = Furnish::Logger.new(Tempfile.new("furnish_log"), 3)
      @sched = Furnish::Scheduler.new
    end

    def teardown
      Furnish.logger.close
      super
    end
  end

  class RunningSchedulerTestCase < SchedulerTestCase
    def teardown
      sched.stop
      super
    end

    def assert_started(name)
      assert_includes(sched.solved, name, 'scheduler thinks it solved it')
      assert(sched.vm_groups[name].first.store[ [name, "startup"].join("-") ], "dummy provisioner for #{name} recorded the startup run")
      refute(sched.vm_groups[name].first.store[ [name, "shutdown"].join("-") ], "dummy provisioner for #{name} has not recorded the shutdown run")
    end

    def assert_shutdown(name, provisioner)
      refute_includes(sched.solved, name, 'scheduler thinks it solved it')
      assert(provisioner.store[ [name, "shutdown"].join("-") ], "dummy provisioner for #{name} recorded the shutdown run")
    end

    def test_provision_cycle
      machine_names = %w[blarg blarg2 blarg3]

      machine_names.each do |name|
        assert(sched.schedule_provision(name, Dummy.new))
      end

      sched.run
      sched.wait_for(*machine_names)

      machine_names.each do |name|
        assert_started(name)
      end

      machine_provs = machine_names.map { |n| sched.vm_groups[n].first }

      sched.teardown

      machine_names.each_with_index do |name, i|
        assert_shutdown(name, machine_provs[i])
      end
    end

    def test_dependent_provision
      # since we can't reliably predict linear order, we just paritition it by
      # how the dependency resolver should sort things out. This isn't perfect by
      # any means, but allows us to check the dependency resolver.
      machine_order = {
        "blarg1" => %w[blarg2 blarg3],
        "blarg2" => %w[blarg4],
        "blarg3" => %w[blarg4],
        "blarg4" => [],
        "blarg5" => []
      }

      assert(sched.schedule_provision('blarg1', Dummy.new))
      assert(sched.schedule_provision('blarg2', Dummy.new, %w[blarg1]))
      assert(sched.schedule_provision('blarg3', Dummy.new, %w[blarg1]))
      assert(sched.schedule_provision('blarg4', Dummy.new, %w[blarg2 blarg3]))
      assert(sched.schedule_provision('blarg5', Dummy.new))

      sched.run
      sched.wait_for(*machine_order.keys)

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

      machine_provs = (1..5).map { |n| sched.vm_groups["blarg#{n}"].first }

      sched.teardown

      1.upto(5) { |x| assert_shutdown("blarg#{x}", machine_provs[x-1]) }
    end

    def test_multiprovision_order
      dummies = [Dummy.new, Dummy.new]
      dummies.each_with_index { |x,i| x.id = i }
      assert(sched.schedule_provision('blarg', dummies))
      sched.run
      sched.wait_for('blarg')
      assert_equal(dummies.map(&:id), dummies.first.call_order.to_a)
      dummies.first.call_order.clear
      assert_empty(dummies.first.call_order.to_a)
      sched.teardown
      assert_equal(dummies.reverse.map(&:id), dummies.first.call_order.to_a)
    end

    def test_single_deprovision
      assert(sched.schedule_provision('blarg', Dummy.new))
      assert(sched.schedule_provision('blarg2', Dummy.new))
      assert(sched.schedule_provision('blarg3', Dummy.new, %w[blarg2]))

      sched.run
      sched.wait_for('blarg', 'blarg2', 'blarg3')

      %w[blarg blarg2 blarg3].each do |name|
        assert_includes(sched.solved, name, "#{name} is in the solved list")
      end

      sched.teardown_group("blarg")

      [sched.solved, sched.vm_groups.keys].each do |coll|
        assert_includes(coll, "blarg2", "blarg2 is still available")
        assert_includes(coll, "blarg3", "blarg3 is still available")
        refute_includes(coll, "blarg", "blarg is not still available")
      end

      #
      # vm_dependencies doesn't track empty references, so deprovisions that have
      # dependencies need some extra checks to ensure their behavior. Basically
      # this just means they can't be tested generically.
      #
      assert_includes(sched.vm_dependencies.keys, "blarg3", "blarg3 still has dependencies")
      sched.teardown_group("blarg3")
      refute_includes(sched.vm_dependencies.keys, "blarg3", "blarg3 still has dependencies")
    end

    def test_run_arguments
      tempfiles = []

      signals = %w[INFO USR2]

      signals.each do |signal|
        if Signal.list[signal] # not everyone has INFO
          Signal.trap(signal) { nil } if Signal.list[signal]

          tf = Tempfile.new('furnish_signal_handlers')
          tempfiles.push(tf)
          Furnish.logger = Furnish::Logger.new(tf)

          sched.run(false)
          Process.kill(signal, Process.pid)

          sched.stop
          sleep 0.1 # wait for any writes to complete

          %w[solved working waiting].each do |section|
            refute_match(/#{section}/, File.read(tf.path), "#{signal} yielded no output with the #{section} set")
          end

          sched.run(true)
          Process.kill(signal, Process.pid)

          sched.stop
          sleep 0.1 # wait for any writes to complete

          %w[solved working waiting].each do |section|
            assert_match(/#{section}/, File.read(tf.path), "#{signal} yielded output with the #{section} set")
          end
        end
      end
    ensure
      tempfiles.each { |f| f.unlink }
    end

    def test_provision_failures
      dummy = StartFailDummy.new
      assert(sched.schedule_provision('blarg', dummy))
      assert_raises(RuntimeError, "Could not provision blarg with provisioner StartFailDummy") do
        sched.run
        sched.wait_for('blarg')
      end
      sched.stop
      sched.deprovision_group('blarg')

      # tests scheduler crashes not keeping the scheduler from being restarted
      assert(sched.schedule_provision('blarg', Dummy.new))
      sched.run
      sched.wait_for('blarg')
      sched.stop
      assert_includes(sched.solved, "blarg")
      sched.teardown
      refute_includes(sched.solved, "blarg")

      dummy = StopFailDummy.new
      assert(sched.schedule_provision('blarg', StopFailDummy.new))
      sched.run
      sched.wait_for('blarg')
      sched.stop
      assert_includes(sched.solved, "blarg")
      assert_raises(RuntimeError) { sched.teardown }
      assert_includes(sched.solved, "blarg")
      sched.force_deprovision = true
      sched.teardown
      refute_includes(sched.solved, "blarg")
    end
  end
end

