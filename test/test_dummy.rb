#
# Just some small tests for the dummy provisioner to ensure it's sane. Since
# it's used heavily in the scheduler tests, it's important to ensure it itself
# works.
#
# That said, the dummy provisioner should not be used for anything "real" and
# this test is largely an exercise in ensuring the rest of the test suite is
# not lying to it. Nothing here gets tested that should be used outside of the
# test suite.
#

require 'helper'

class TestDummy < Furnish::TestCase
  def test_defaults
    dummy = Dummy.new
    dummy.name = 'dummy_test'
    assert(dummy.startup, 'startup returns true by default')
    assert(dummy.shutdown, 'shutdown returns true by default')
    assert_equal(['dummy_test'], dummy.report, 'report returns boxed name by default')

    obj = Palsy::Object.new('dummy')
    %w[startup shutdown report].each do |meth|
      assert(obj["dummy_test-#{meth}"], "#{meth} persists a breadcrumb when run")
    end
  end

  def test_order_check
    machine_names = %w[one two three]
    machine_names.each do |name|
      dummy = Dummy.new
      dummy.name = name
      assert(dummy.startup)
    end

    dummy = Dummy.new
    assert_kind_of(Furnish::Provisioner::Dummy, dummy)
    assert_equal(machine_names, dummy.order.to_a, 'order was respected')

    assert(dummy.order.clear)
    assert_empty(dummy.order.to_a)

    machine_names.each do |name|
      dummy = Dummy.new
      dummy.name = name
      assert(dummy.shutdown)
    end

    dummy = Dummy.new
    assert_kind_of(Furnish::Provisioner::Dummy, dummy)
    assert_equal(machine_names, dummy.order.to_a, 'order was respected')
  end

  def test_call_order
    dummies = Dummy.new, Dummy.new
    dummies.each_with_index do |x, i|
      x.name = "foo"
      x.id = "foo#{i}"
      assert(x.startup)
    end

    assert_equal(dummies.map(&:id), dummies.first.call_order.to_a)

    dummies.first.call_order.clear

    dummies.reverse.each do |x|
      assert(x.startup)
    end

    assert_equal(dummies.reverse.map(&:id), dummies.first.call_order.to_a)
  end

  def test_delegation_and_marshal
    #
    # This test is so jammed together because the way marshal operates on the
    # dummy largely depends on the delegates existing to test properly (they
    # can't be marshalled)
    #

    delegates = {
      "startup"   => proc { false },
      "shutdown"  => proc { 1 },
      "report"    => proc { [1] }
    }

    dummy = Dummy.new(delegates)
    dummy.name = "dummy_delegation_test"
    assert_equal(false, dummy.startup, 'startup delegates to to the proc instead of the default')
    assert_equal(1, dummy.shutdown, 'shutdown delegates to the proc instead of the default')
    assert_equal([1], dummy.report, 'report delegates to the proc instead of the default')

    obj = Palsy::Object.new('dummy')
    %w[startup shutdown report].each do |meth|
      assert(obj["dummy_delegation_test-#{meth}"], "#{meth} persists a breadcrumb when run")
    end

    str = Marshal.dump(dummy)
    refute_empty(str, "dummy was dumped successfully")

    newobj = Marshal.load(str)
    assert_kind_of(Furnish::Provisioner::Dummy, newobj)
    refute_equal(dummy.object_id, newobj.object_id)

    assert_equal(delegates, dummy.delegates)
    refute_equal(delegates, newobj.delegates, "newobj doesn't get to keep delegates")

    assert_equal(obj, dummy.store, "palsy object persists")
    assert_equal(obj, newobj.store, "palsy object persists")
  end
end
