require 'helper'
require 'tempfile'

class TestLogger < Furnish::TestCase
  def setup
    super
    @logger_file = Tempfile.new('furnish_log')
    @logger = Furnish::Logger.new(@logger_file, 'w')
  end

  def test_assert
    assert(true)
  end

  def teardown
    @logger.close
    @logger_file.unlink
    super
  end
end
