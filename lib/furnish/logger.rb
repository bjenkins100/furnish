require 'logger'
require 'thread'

module Furnish
  class Logger
    attr_accessor :debug_level
    attr_reader   :io

    def initialize(logger_io=$stderr, debug_level=0)
      @write_mutex = Mutex.new
      @io = logger_io
      @io.sync = true
      @debug_level = debug_level
    end

    def if_debug(level=1, else_block=nil, &block)
      @write_mutex.synchronize do
        if debug_level >= level and block
          io.instance_eval(&block)
        elsif else_block
          io.instance_eval(&else_block)
        end
      end
    end

    def method_missing(sym, *args)
      raise NoMethodError, "#{io.inspect} has no method #{sym}" unless io.respond_to?(sym)
      @write_mutex.synchronize { io.__send__(sym, *args) }
    end
  end
end
