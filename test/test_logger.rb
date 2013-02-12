require 'helper'
require 'tempfile'

class TestLogger < Furnish::TestCase
  def setup
    super
    @logger_file = Tempfile.new('furnish_log')
    @logger = Furnish::Logger.new(@logger_file, 'w')
  end

  def test_defaults
    logger = Furnish::Logger.new
    assert_equal($stderr, logger.io, "logger io obj is stderr by default")
    assert_equal(0, logger.debug_level, "logger debug level is 0 by default")
  end

  def test_logger_behaves_like_io
    @logger.puts "ohai"
    assert_equal("ohai\n", File.read(@logger_file.path))
  end

  def teardown
    @logger.close
    @logger_file.unlink
    super
  end
end
