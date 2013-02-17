module Furnish
  module Provisioner
    #
    # Primarily for testing, this is a provisioner that has a basic storage
    # model.
    #
    # Note that while suitable for testing, its use of procs makes it
    # impossible to marshal cleanly, making it nearly useless with the
    # persistence layer and thus cannot be relied on.
    #
    # In short, unless you're writing tests you should probably never use this
    # code.
    #
    class Dummy

      #
      # Some dancing around the marshal issues with this provisioner. Note that
      # after restoration, any delegates you set will no longer exist, so
      # relying on scheduler persistence is a really bad idea.
      #

      def marshal_dump
        [ name, @store, @order, @call_order ]
      end

      def marshal_load(obj)
        @name, @store, @order, @call_order = obj
        @delegates ||= { }
      end

      attr_reader   :delegates
      attr_reader   :store
      attr_reader   :order
      attr_reader   :call_order
      attr_accessor :name

      def initialize(delegates={})
        @store = Palsy::Object.new('dummy')
        @order = Palsy::List.new('dummy_order', 'shared')
        @delegates = delegates
      end

      def report
        do_delegate(__method__) do
          [name]
        end
      end

      def startup(*args)
        do_delegate(__method__) do
          true
        end
      end

      def shutdown
        do_delegate(__method__) do
          true
        end
      end

      def do_delegate(meth_name)
        meth_name = meth_name.to_s

        @call_order = Palsy::List.new('dummy_order', name)
        # indicate we actually did something
        @store[ [name, meth_name].join("-") ] = Time.now.to_i
        @order.push(name)
        @call_order.push(object_id)

        # if we have overridden functionality, run that.
        if @delegates[meth_name]
          @delegates[meth_name].call
        else
          yield
        end
      end
    end
  end
end
