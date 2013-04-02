require 'helper'

class APIDummy < Furnish::Provisioner::API
  attr_accessor :foo
end

class TestAPI < Furnish::TestCase
  def setup
    super
    @klass = APIDummy
  end

  def test_constructor
    assert_raises(ArgumentError, "Arguments must be a kind of hash") { @klass.new(nil) }
    obj = @klass.new(:foo => 1)
    assert_equal(1, obj.foo, "attrs are set based on contents of constructor")
    assert_raises(NoMethodError) { @klass.new(:quux => 2) }
  end

  def test_interface
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
end
