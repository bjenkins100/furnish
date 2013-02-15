require 'bundler/setup'
require 'minitest/unit'
require 'tempfile'
require 'simplecov'
require 'furnish'

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
end

require 'minitest/autorun'
