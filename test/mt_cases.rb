require 'dummy_classes'
require 'furnish/test'

module Furnish
  # These tests are run for both threaded and serial cases.
  class RestartingSchedulerTestCase < SchedulerTestCase
    def teardown
      sched.stop
      super
    end

    def assert_started(name)
      assert_includes(sched.vm.solved, name, 'scheduler thinks it solved it')
      assert(sched.vm.groups[name].first.store[ [name, "startup"].join("-") ], "dummy provisioner for #{name} recorded the startup run")
      refute(sched.vm.groups[name].first.store[ [name, "shutdown"].join("-") ], "dummy provisioner for #{name} has not recorded the shutdown run")
    end

    def assert_shutdown(name, provisioner)
      refute_includes(sched.vm.solved, name, 'scheduler thinks it solved it')
      assert(provisioner.store[ [name, "shutdown"].join("-") ], "dummy provisioner for #{name} recorded the shutdown run")
    end

    def test_recovery_mode
      [RecoverableDummy, RaisingRecoverableDummy].each do |prov|
        test1 = "#{prov}-test1"
        test2 = "#{prov}-test2"
        test3 = "#{prov}-test3"

        sched.s(test1, Dummy.new)
        sched.s(test2, prov.new)
        sched.run rescue nil # FIXME oof. maybe move this to indepedent tests for serial mode?
        assert(sched.serial || sched.running?)
        unless sched.serial
          sleep 0.1 while !sched.needs_recovery.has_key?(test2)
        end
        assert(sched.needs_recovery?)
        assert_includes(sched.needs_recovery.keys, test2)
        refute_solved(test2)
        sched.s(test3, Dummy.new, [test2])
        refute_solved(test3)
        assert(sched.serial || sched.running?)
        assert_empty(sched.recover)
        assert(sched.serial || sched.running?)
        if sched.serial
          sched.run rescue nil
        end
        sched.wait_for(test1, test2, test3)
        assert_started(test2)
        assert_started(test3)
        assert_started(test1)
        sched.teardown
        sched.stop

        test4 = "#{prov}-test4"
        test5 = "#{prov}-test5"

        [test1, test2, test3, test4, test5].each { |x| x.replace(x + "-permfail") }

        sched.s(test1, Dummy.new)
        sched.s(test2, prov.new)
        sched.s(test3, Dummy.new, [test2])
        sched.s(test4, FailedRecoverDummy.new)
        sched.s(test5, Dummy.new, [test4])
        sched.run rescue nil
        if sched.serial
          assert(sched.needs_recovery?)
        end
        sched.run rescue nil
        assert(sched.serial || sched.running?)
        unless sched.serial
          sleep 0.1 while !sched.needs_recovery.has_key?(test2)
          sleep 0.1 while !sched.needs_recovery.has_key?(test4)
        end
        assert(sched.needs_recovery?)
        refute_solved(test2)
        refute_solved(test3)
        refute_solved(test4)
        assert(sched.serial || sched.running?)
        assert_equal({ test4 => false }, sched.recover)
        assert(sched.serial || sched.running?)
        if sched.serial
          sched.run rescue nil
        end
        sched.wait_for(test1, test2, test3)
        assert_started(test2)
        assert_started(test3)
        assert_started(test1)
        refute_solved(test4)
        refute_solved(test5)
        sched.force_deprovision = true
        sched.deprovision_group(test4)
        sched.force_deprovision = false
        refute_includes(sched.needs_recovery.keys, test4)
        refute(sched.needs_recovery?)
        sched.s(test4, Dummy.new)
        if sched.serial
          sched.run
        end
        assert(sched.serial || sched.running?)
        sched.wait_for(test4, test5)
        assert_solved(test4) # we tore it down, so assert_started will break here.
        assert_started(test5)
        sched.teardown
        sched.stop
      end
    end

    def test_run_tracking
      #--
      # This is a tad convoluted. Dummy's startup method sets an ivar which
      # should be persisted. Then, we retrieve it by examining the result of
      # the report method, which regurgitates it.
      #
      # This ensures that after startup, the provisioner has had its state
      # tracked, ensuring the correct state.
      #++

      assert(sched.schedule_provision('test1', Dummy.new))
      sched.run
      sched.wait_for('test1')
      assert_started('test1')
      assert_equal("floop", sched.vm.groups['test1'].first.report.last, 'state was stored after provision success')

      assert(sched.schedule_provision('test2', [Dummy.new, StartFailDummy.new], []))
      sched.run rescue nil # FIXME oof. maybe move this to indepedent tests for serial mode?
      unless sched.serial
        sleep 0.1 while !sched.needs_recovery.has_key?('test2')
      end
      assert(sched.serial || sched.running?)
      assert_includes(sched.needs_recovery.keys, 'test2')
      assert_equal("floop", sched.vm.groups['test2'].first.report.last, "provision failed but state is still stored for the provisions that succeeded")
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

      machine_provs = machine_names.map { |n| sched.vm.groups[n].first }

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

      machine_provs = (1..5).map { |n| sched.vm.groups["blarg#{n}"].first }

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
        assert_includes(sched.vm.solved, name, "#{name} is in the solved list")
      end

      sched.teardown_group("blarg")

      [sched.vm.solved, sched.vm.groups.keys].each do |coll|
        assert_includes(coll, "blarg2", "blarg2 is still available")
        assert_includes(coll, "blarg3", "blarg3 is still available")
        refute_includes(coll, "blarg", "blarg is not still available")
      end

      #
      # vm.dependencies doesn't track empty references, so deprovisions that have
      # dependencies need some extra checks to ensure their behavior. Basically
      # this just means they can't be tested generically.
      #
      assert_includes(sched.vm.dependencies.keys, "blarg3", "blarg3 still has dependencies")
      sched.teardown_group("blarg3")
      refute_includes(sched.vm.dependencies.keys, "blarg3", "blarg3 still has dependencies")
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

          sched.signal_handler = false
          sched.run
          Process.kill(signal, Process.pid)

          sched.stop
          sleep 0.1 # wait for any writes to complete

          %w[solved working waiting provisioning].each do |section|
            refute_match(/#{section}/, File.read(tf.path), "#{signal} yielded no output with the #{section} set")
          end

          sched.signal_handler = true
          sched.run
          Process.kill(signal, Process.pid)

          sched.stop
          sleep 0.1 # wait for any writes to complete

          %w[solved working waiting provisioning].each do |section|
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
      sched.run rescue nil # FIXME oof. maybe move this to indepedent tests for serial mode?
      if !sched.serial
        sleep 0.1 while !sched.needs_recovery.has_key?('blarg')
      end
      assert(sched.serial || sched.running?, 'still running after failure')
      assert_includes(sched.needs_recovery, 'blarg')
      sched.stop
      sched.deprovision_group('blarg')

      # tests scheduler crashes not keeping the scheduler from being restarted
      assert(sched.schedule_provision('blarg', Dummy.new))
      sched.run
      sched.wait_for('blarg')
      sched.stop
      assert_includes(sched.vm.solved, "blarg")
      sched.teardown
      refute_includes(sched.vm.solved, "blarg")

      dummy = StopFailDummy.new
      assert(sched.schedule_provision('blarg', StopFailDummy.new))
      sched.run
      sched.wait_for('blarg')
      sched.stop
      assert_includes(sched.vm.solved, "blarg")
      assert_raises(RuntimeError) { sched.teardown }
      assert_includes(sched.vm.solved, "blarg")
      sched.force_deprovision = true
      sched.teardown
      refute_includes(sched.vm.solved, "blarg")
    end
  end
end

