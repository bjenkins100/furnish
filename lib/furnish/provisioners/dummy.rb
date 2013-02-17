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

      attr_reader   :store
      attr_reader   :order
      attr_accessor :name
      attr_accessor :id

      def initialize
        @store = Palsy::Object.new('dummy')
        @order = Palsy::List.new('dummy_order', 'shared')
      end

      def call_order
        @call_order ||= Palsy::List.new('dummy_order', name)
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

        # indicate we actually did something
        @store[ [name, meth_name].join("-") ] = Time.now.to_i
        @order.push(name)
        call_order.push(id || "unknown")

        yield
      end
    end
  end
end
