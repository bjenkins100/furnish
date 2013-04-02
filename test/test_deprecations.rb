require 'helper'
require 'stringio'

class BadDummy < Furnish::Provisioner::Dummy
  attr_accessor :name

  # exists to check name fetching on provision failure (sent to log)
  def startup(*args)
    return false
  end

  # this retardation lets us make it look like furnish_group_name doesn't exist
  def respond_to?(arg)
    super unless [:furnish_group_name, :furnish_group_name=].include?(arg)
  end
end

class TestDeprecations < Furnish::SchedulerTestCase
  def setup
    super
    @monitor.kill
    @stringio = StringIO.new
    Furnish.logger = Furnish::Logger.new(@stringio, 3)
  end

  def test_name_rename
    obj = BadDummy.new
    sched.serial = true
    sched.schedule_provision('test1', obj)
    assert_match(/is using a deprecated API by providing #name as an accessor/, @stringio.string)
    assert_match(/Please adjust to use #furnish_group_name instead/, @stringio.string)
    @stringio.string = ''
    assert_raises(RuntimeError) { sched.run }
    assert_match(/is using a deprecated API by providing #name as an accessor/, @stringio.string)
    assert_match(/Please adjust to use #furnish_group_name instead/, @stringio.string)
  ensure
    sched.teardown
  end
end
