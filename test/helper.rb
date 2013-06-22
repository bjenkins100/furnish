require 'bundler/setup'

if ENV["COVERAGE"]
  require 'simplecov'
  SimpleCov.start do
    add_filter '/test/'
  end
end

require 'tempfile'
require 'furnish'
require 'furnish/test'

require 'minitest/autorun'
