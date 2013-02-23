module Furnish
  #
  # A standard namespace for provisioners, which Furnish does not provide
  # itself as a part of the release.
  #
  # Nothing to see here, really.
  #
  module Provisioner
    #
    # Primarily for testing, this is a provisioner that has a basic storage
    # model.
    #
    # In short, unless you're writing tests you should probably never use this
    # code.
    #
    class Dummy

      #--
      # Some dancing around the marshal issues with this provisioner. Note that
      # after restoration, any delegates you set will no longer exist, so
      # relying on scheduler persistence is a really bad idea.
      #++

      # basic Palsy::Object store for stuffing random stuff
      attr_reader   :store
      # order tracking via Palsy::List, delegation makes a breadcrumb here
      # that's ordered between all provisioners.
      attr_reader   :order
      # name of the provisioner according to the API
      attr_accessor :name
      # arbitrary identifier for Dummy#call_order
      attr_accessor :id

      #
      # Construct a Dummy.
      #
      def initialize
        @store = Palsy::Object.new('dummy')
        @order = Palsy::List.new('dummy_order', 'shared')
      end

      #
      # call order is ordering on a per-provisioner group basis, and is used to
      # validate that groups do indeed execute in the proper order.
      #
      def call_order
        @call_order ||= Palsy::List.new('dummy_order', name)
      end

      #
      # report shim
      #
      def report
        do_delegate(__method__) do
          [name]
        end
      end

      #
      # startup shim
      #
      def startup(*args)
        do_delegate(__method__) do
          true
        end
      end

      #
      # shutdown shim
      #
      def shutdown
        do_delegate(__method__) do
          true
        end
      end

      #
      # Helper to trace calls to this provisioner. Pretty much everything we
      # care about goes through here.
      #
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
