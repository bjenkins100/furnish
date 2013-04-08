require 'helper'

class TestAPI < Furnish::TestCase
  def setup
    super
    # NOTE this class is defined in test/dummy_classes.rb
    @klass = APIDummy
  end

  def test_constructor
    assert_raises(ArgumentError, "Arguments must be a kind of hash") { @klass.new(nil) }
    obj = @klass.new(:foo => 1)
    assert_equal(1, obj.foo, "attrs are set based on contents of constructor")
    assert_raises(ArgumentError) { @klass.new(:quux => 2) }
    assert_raises(ArgumentError) { @klass.new(:bar => 2) }
    assert_raises(ArgumentError) { @klass.new(:foo => "string") }
  end

  def test_interface
    assert_respond_to(@klass, :furnish_properties)
    assert_respond_to(@klass, :furnish_property)

    assert_kind_of(Hash, @klass.furnish_properties)
    assert_includes(@klass.furnish_properties, :foo)
    assert_includes(@klass.furnish_properties, :a_string)
    refute_includes(@klass.furnish_properties, :bar)
    assert_kind_of(Hash, @klass.furnish_properties[:foo])
    assert_equal("does things with foo", @klass.furnish_properties[:foo][:description])
    assert_equal(Integer, @klass.furnish_properties[:foo][:type])

    obj = @klass.new(:foo => 1)

    assert_respond_to(obj, :furnish_group_name)
    assert_respond_to(obj, :furnish_group_name=)

    %w[startup shutdown].each do |meth|
      assert_raises(NotImplementedError, "#{meth} method not implemented for #{@klass.name}") { obj.send(meth) }
    end
  end

  def test_report
    obj = @klass.new(:foo => 1)
    assert_equal(["unknown"], obj.report, "default report uses 'unknown' as the group name")
    obj.furnish_group_name = "frobnik"
    assert_equal(["frobnik"], obj.report, "when furnish_group_name is set, uses that in the report")
  end

  def test_to_s
    obj = @klass.new(:foo => 1)
    assert_equal("unknown[#{@klass.name}]", obj.to_s, "formatted properly without a furnish group name")
    obj.furnish_group_name = "frobnik"
    assert_equal("frobnik[#{@klass.name}]", obj.to_s, "formatted properly without a furnish group name")
  end

  def test_equality
    assert_equal(Dummy.new, Dummy.new)
    assert_equal(APIDummy.new(:foo => 1), APIDummy.new(:foo => 1))
    refute_equal(APIDummy.new(:foo => 2), APIDummy.new(:foo => 1))
    refute_equal(Dummy.new, StopFailDummy.new)
  end

  def test_recovery
    prov = APIDummy.new
    refute(prov.recover(:startup, nil))
    prov = BrokenRecoverAPIDummy.new
    assert_raises(NotImplementedError) { prov.recover(:startup, nil) }
  end
end
