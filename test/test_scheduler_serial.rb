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

  def test_run_arguments
    tempfiles = []

    clear_signal = lambda do |sig|
      Signal.trap(sig) { nil } if Signal.list[sig]
    end

    signals = %w[INFO USR2]

    # flush any previous scheduler runs which might have set signals with null
    # handlers
    signals.each(&clear_signal)

    signals.each do |signal|
      clear_signal.call(signal)

      if Signal.list[signal] # not everyone has INFO
        tf = Tempfile.new('furnish_signal_handlers')
        tempfiles.push(tf)
        Furnish.logger = Furnish::Logger.new(tf)

        sched.run(false)
        Process.kill(signal, Process.pid)

        sleep 0.1 # wait for any writes to complete

        %w[solved working waiting].each do |section|
          refute_match(/#{section}/, File.read(tf.path), "#{signal} yielded no output with the #{section} set")
        end

        sched.run(true)
        Process.kill(signal, Process.pid)

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
