require 'logger'
require 'thread'

module Furnish
  #
  # Furnish::Logger is a thread safe, auto-flushing, IO-delegating logger with
  # numeric level control.
  #
  # See Furnish::Logger::Mixins for functionality you can add to your
  # provisioners to deal with loggers easily.
  #
  # Example:
  #
  #   # debug level is 0
  #   logger = Furnish::Logger.new($stderr, 0)
  #   # IO methods are sent straight to the IO object, synchronized by a
  #   # mutex:
  #   logger.puts "foo"
  #   logger.print "foo"
  #
  #   # if_debug is a way to scope log writes:
  #
  #   # this will never run because debug level is 0
  #   logger.if_debug(1) do
  #     # self is the IO object here
  #     puts "foo"
  #   end
  #
  #   logger.if_debug(0) do # this will run
  #     puts "foo"
  #   end
  #
  #   logger.debug_level = 2
  #
  #   # if_debug's parameter merely must equal or be less than the debug
  #   # level to process.
  #   logger.if_debug(1) do # will run
  #     puts "bar"
  #   end
  #
  class Logger

    #
    # Intended to be mixed in by other classes, provides an API for dealing
    # with the standard logger object set as Furnish.logger.
    #
    module Mixins
      #
      # Delegates to Furnish::Logger#if_debug.
      #
      def if_debug(*args, &block)
        Furnish.logger.if_debug(*args, &block)
      end
    end

    #
    # Set the debug level - adjustable after creation.
    #
    attr_accessor :debug_level

    #
    # The IO object. Probably best to not mess with this attribute directly,
    # most methods will be proxied to it.
    #
    attr_reader   :io

    #
    # Create a new Furnish::Logger. Takes an IO object and an Integer debug
    # level. See Furnish::Logger class documentation for more information.
    #
    def initialize(logger_io=$stderr, debug_level=0)
      @write_mutex = Mutex.new
      @io = logger_io
      @io.sync = true
      @debug_level = debug_level
    end

    #
    # Runs the block if the level is equal to or lesser than the
    # Furnish::Logger#debug_level. The default debug level is 1.
    #
    # The block runs in the context of the Furnish::Logger#io object, that is,
    # `self` is the IO object.
    #
    # If an additional proc is applied, will run that if the debug block would
    # *not* fire, effectively creating an else. Generally an anti-pattern, but
    # is useful in a few situations.
    #
    # if_debug is synchronized over the logger's mutex.
    #
    def if_debug(level=1, else_block=nil, &block)
      @write_mutex.synchronize do
        if debug_level >= level and block
          io.instance_eval(&block)
        elsif else_block
          io.instance_eval(&else_block)
        end
      end
    end

    #
    # Delegates to the Furnish::Logger#io if possible. If not possible, raises
    # a NoMethodError. All calls are synchronized over the logger's mutex.
    #
    def method_missing(sym, *args)
      raise NoMethodError, "#{io.inspect} has no method #{sym}" unless io.respond_to?(sym)
      @write_mutex.synchronize { io.__send__(sym, *args) }
    end
  end
end
