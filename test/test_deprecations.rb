require 'helper'
require 'stringio'

class TestDeprecations < Furnish::SchedulerTestCase
  def setup
    super
    @monitor.kill
    @stringio = StringIO.new
    Furnish.logger = Furnish::Logger.new(@stringio, 3)
  end

  def test_name_rename
    # NOTE this class is defined in test/dummy_classes.rb
    obj = BadDummy.new
    sched.serial = true
    sched.schedule_provision('test1', obj)
    assert_match(/is using a deprecated API by providing #name as an accessor/, @stringio.string)
    assert_match(/Please adjust to use #furnish_group_name instead/, @stringio.string)
  ensure
    sched.teardown
  end
end
