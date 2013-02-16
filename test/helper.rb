require 'bundler/setup'
require 'minitest/unit'
require 'tempfile'
require 'simplecov'
require 'furnish'
require 'furnish/provisioners/dummy'

Dummy = Furnish::Provisioner::Dummy unless defined? Dummy

SimpleCov.start if ENV["COVERAGE"]

module Furnish
  class TestCase < MiniTest::Unit::TestCase

    def reinit
      @tempfiles ||= []
      file = Tempfile.new('furnish_db')
      @tempfiles.push(file)
      Furnish.init(file.path)
      return file
    end

    def setup
      reinit
    end

    def teardown
      Furnish.shutdown
      @tempfiles.each do |file|
        file.unlink
      end
    end
  end

  class SchedulerTestCase < TestCase
    def setup
      super
      Furnish.logger = Furnish::Logger.new(Tempfile.new("furnish_log"), 3)
    end

    def teardown
      Furnish.logger.close
      super
    end
  end
end

require 'minitest/autorun'
