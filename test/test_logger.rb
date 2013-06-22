require 'helper'
require 'tempfile'
require 'stringio'

class TestLogger < Furnish::Test
  def setup
    super
    @logger_file = Tempfile.new('furnish_log')
    @logger = Furnish::Logger.new(@logger_file)
  end

  def read_logfile
    File.read(@logger_file.path)
  end

  def test_defaults
    logger = Furnish::Logger.new
    assert_equal($stderr, logger.io, "logger io obj is stderr by default")
    assert_equal(0, logger.debug_level, "logger debug level is 0 by default")
  end

  def test_logger_behaves_like_io
    @logger.puts "ohai"
    assert_equal("ohai\n", read_logfile)
  end

  def test_if_debug
    assert_equal(0, @logger.debug_level, "debug level is 0")
    @logger.if_debug do
      puts "foo"
    end

    assert_empty(read_logfile, "debug level is zero and if_debug defaults at 1")

    @logger.debug_level = 1
    @logger.if_debug do
      puts "foo"
    end

    assert_equal("foo\n", read_logfile, "debug level is 1")

    @logger.if_debug(2) do
      puts "bar"
    end

    assert_equal("foo\n", read_logfile, "debug level is 1 and if_debug is 2")

    else_block = proc { puts "quux" }

    @logger.if_debug(2, else_block) do
      puts "should_not_get_here"
    end

    assert_equal("foo\nquux\n", read_logfile, "debug level is 1 and else block triggered")

    @logger.debug_level = 2
    @logger.if_debug(1) do
      puts "level2"
    end

    assert_equal("foo\nquux\nlevel2\n", read_logfile, "debug level is 2 and if_debug checking for 1")
  end

  def test_redirect
    @logger.debug_level = 3
    io = StringIO.new('', 'w')
    @logger.redirect(io) do
      @logger.if_debug do
        puts "herp"
      end
    end

    @logger.if_debug do
      puts "derp"
    end

    assert_equal("derp\n", read_logfile)
    assert_equal("herp\n", io.string)
  end

  def test_with_tag
    @logger.debug_level = 3
    @logger.with_tag("fart") do
      @logger.if_debug do
        puts "hello"
      end
    end

    @logger.if_debug do
      puts "hello"
    end

    assert_equal("[fart] hello\nhello\n", read_logfile)
  end

  def test_api_has_logger
    old_logger = Furnish.logger
    io = StringIO.new('', 'w')
    Furnish.logger = Furnish::Logger.new(io, 3)

    d = Furnish::Provisioner::Dummy.new
    d.make_log

    assert_equal("hello from Dummy\n", io.string)
  ensure
    Furnish.logger = old_logger
  end

  def teardown
    @logger.close
    @logger_file.unlink
    super
  end
end
