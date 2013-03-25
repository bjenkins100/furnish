require 'helper'

class TestProvisionerGroup < Furnish::TestCase
  def test_constructor
    dummy = Dummy.new
    pg = Furnish::ProvisionerGroup.new(dummy, 'blarg')
    assert_includes(pg, dummy)
    assert_equal('blarg', pg.name)
    assert_kind_of(Set, pg.dependencies)
    assert_empty(pg.dependencies)
    assert_equal('blarg', dummy.name)

    dummy = Dummy.new
    pg = Furnish::ProvisionerGroup.new([dummy], 'blarg2', %w[blarg])
    assert_includes(pg, dummy)
    assert_equal('blarg2', pg.name)
    assert_equal(Set['blarg'], pg.dependencies)
    assert_equal('blarg2', dummy.name)
  end

  def test_up_down
    Furnish.logger.puts "Testing logging, output muted"

    require 'stringio'
    Furnish.logger = Furnish::Logger.new(StringIO.new, 3)

    store = Palsy::Object.new('dummy')
    dummy = Dummy.new
    pg = Furnish::ProvisionerGroup.new(dummy, 'blarg')

    assert(pg.startup, 'started')
    assert(store[ [pg.name, 'startup'].join("-") ], 'startup ran')
    assert(pg.shutdown, 'stopped')
    assert(store[ [pg.name, 'startup'].join("-") ], 'shutdown ran')

    dummy = StartFailDummy.new
    pg = Furnish::ProvisionerGroup.new(dummy, 'blarg2')
    assert_raises(RuntimeError, "Could not provision #{pg.name} with provisioner #{dummy.class.name}") { pg.startup }

    dummy = StopFailDummy.new
    pg = Furnish::ProvisionerGroup.new(dummy, 'blarg3')
    assert_raises(RuntimeError, "Could not deprovision #{pg.name}/#{dummy.class.name}") { pg.shutdown }
    pg.shutdown(true)

    dummy = StartExceptionDummy.new
    pg = Furnish::ProvisionerGroup.new(dummy, 'blarg4')
    assert_raises(RuntimeError, "Could not provision #{pg.name} with provisioner #{dummy.class.name}") { pg.startup }

    dummy = StopExceptionDummy.new
    pg = Furnish::ProvisionerGroup.new(dummy, 'blarg4')
    assert_raises(RuntimeError, "Could not deprovision #{pg.name}/#{dummy.class.name}") { pg.shutdown }
    pg.shutdown(true)
    sleep 0.1 # wait for flush
    assert_match(%r!Deprovision #{dummy.class.name}/#{pg.name} had errors:!, Furnish.logger.string)
  end
end
