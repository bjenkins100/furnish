require 'logger'

module Furnish
  class Logger
    attr_accessor :debug_level

    def initialize(logger_io=$stderr, debug_level=0)
      raise ArgumentError, "logger device must be a kind of IO" unless @io.kind_of?(IO)
      @io = logger_io
      @io.sync = true
      @debug_level = debug_level
    end

    def if_debug(level=1, else_block=nil, &block)
      if level >= debug_level and block
        instance_eval(&block)
      elsif else_block
        instance_eval(&else_block)
      end
    end

    def method_missing(sym, *args)
      raise NoMethodError unless @io.respond_to?(sym)
      @io.__send__(sym, *args)
    end
  end
end
