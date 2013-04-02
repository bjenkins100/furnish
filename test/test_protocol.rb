require 'helper'

class TestProtocol < Furnish::TestCase
  #--
  # see the Furnish::Protocol docs for truth tables and whatnot
  #++

  def test_setters
    proto = Furnish::Protocol.new
    assert_equal([:requires, :accepts, :yields], Furnish::Protocol::VALIDATOR_NAMES)

    Furnish::Protocol::VALIDATOR_NAMES.each do |vname|
      proto.send(vname, :foo, "a description", Integer)
      assert_includes(proto[vname], :foo)
      assert_equal({ :description => "a description", :type => Integer }, proto[vname][:foo])
      proto.send(vname, "bar")
      assert_includes(proto[vname], :bar)
      assert_equal({ :description => "", :type => Object }, proto[vname][:bar])
    end

    refute(proto[:accepts_from_any])
    proto.accepts_from_any(true)
    assert(proto[:accepts_from_any])
  end

  def test_configure
    proto = Furnish::Protocol.new
    proto.configure do
      requires :foo, "a description", Integer
      accepts "bar"
      yields :quux, "another description", Hash
    end

    assert_includes(proto[:requires], :foo)
    assert_includes(proto[:accepts], :bar)
    assert_includes(proto[:yields], :quux)

    assert_equal(
      { :description => "a description", :type => Integer },
      proto[:requires][:foo]
    )

    assert_equal(
      { :description => "", :type => Object },
      proto[:accepts][:bar]
    )

    assert_equal(
      { :description => "another description", :type => Hash },
      proto[:yields][:quux]
    )

    proto = Furnish::Protocol.new

    assert_raises(RuntimeError) do
      proto.configure do
        accepts_from(Furnish::Protocol.new)
      end
    end

    proto = Furnish::Protocol.new

    assert_raises(RuntimeError) do
      proto.configure do
        requires_from(Furnish::Protocol.new)
      end
    end
  end

  def test_requires_from
    proto1 = Furnish::Protocol.new
    proto2 = Furnish::Protocol.new

    assert(proto2.requires_from(nil))

    proto1.yields(:bar)
    proto2.requires(:bar)

    assert(proto2.requires_from(proto1))

    proto1 = Furnish::Protocol.new
    refute(proto2.requires_from(proto1))

    proto1.yields(:bar)
    proto2 = Furnish::Protocol.new

    assert(proto2.requires_from(proto1))

    proto2.requires(:bar)
    proto2.requires(:quux)

    refute(proto2.requires_from(proto1))
  end

  def test_accepts_from
    proto1 = Furnish::Protocol.new
    proto2 = Furnish::Protocol.new

    assert(proto2.accepts_from(nil))

    proto1.yields(:bar)
    proto2.accepts(:bar)

    assert(proto2.accepts_from(proto1))

    proto1 = Furnish::Protocol.new
    refute(proto2.accepts_from(proto1))

    proto1.yields(:foo)
    refute(proto2.accepts_from(proto1))

    proto2.accepts_from_any(true)
    assert(proto2.accepts_from(proto1))

    proto1 = Furnish::Protocol.new
    proto2 = Furnish::Protocol.new
    proto2.accepts(:quux)
    proto2.accepts(:bar)
    proto1.yields(:quux)

    assert(proto2.accepts_from(proto1))
  end
end
