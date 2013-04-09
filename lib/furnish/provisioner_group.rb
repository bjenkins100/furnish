require 'delegate'
require 'furnish/logger'
require 'furnish/provisioners/api'

module Furnish
  #
  # A provisioner group is an array of provisioners. See Furnish::Provisioner
  # for what the Provisioner API looks like.
  #
  # A group has a set of provisioner objects, a name for the group, and a list
  # of names that count as dependencies. It has methods to operate on the group
  # as a unit, starting them up as a unit and shutting them down. It is
  # primarily operated on by Furnish::Scheduler.
  #
  # In general, you interact with this class via
  # Furnish::Scheduler#schedule_provision, but you can also construct groups
  # yourself and deal with them via
  # Furnish::Scheduler#schedule_provisioner_group.
  #
  # It delegates to Array and can be treated like one via the semantics of
  # Ruby's DelegateClass.
  #
  class ProvisionerGroup < DelegateClass(Array)

    include Furnish::Logger::Mixins

    # The name of the group.
    attr_reader :name
    # The list of names the group depends on.
    attr_reader :dependencies
    # group state object. should not be used outside of internals.
    attr_reader :group_state

    #
    # Create a new Provisioner group.
    #
    # * provisioners can be an array of provisioner objects or a single item
    #   (which will be boxed). This is what the array consists of that this
    #   object is.
    # * furnish_group_name is a string. always.
    # * dependencies can either be passed as an Array or Set, and will be
    #   converted to a Set if they are not a Set.
    #
    # See #assert_provisioner_protocol, Furnish::Protocol, and
    # Furnish::Provisioner::API for information on how a set of provisioner
    # objects will be validated during the construction of the group.
    #
    def initialize(provisioners, furnish_group_name, dependencies=[])
      @group_state = Palsy::Map.new('vm_group_state', furnish_group_name)

      #
      # FIXME maybe move the naming construct to here instead of populating it
      #       out to the provisioners
      #

      provisioners = [provisioners].compact unless provisioners.kind_of?(Array)

      if provisioners.empty?
        raise ArgumentError, "A non-empty list of provisioners must be provided"
      end

      provisioners.each do |prov|
        prov.furnish_group_name = furnish_group_name
      end

      @name         = furnish_group_name
      @dependencies = dependencies.kind_of?(Set) ? dependencies : Set[*dependencies]

      assert_provisioner_protocol(provisioners)

      super(provisioners)
    end

    #
    # Asserts that all the provisioners can communicate with each other.
    #
    # This leverages the Furnish::Protocol#requires_from and
    # Furnish::Protocol#accepts_from assertions and raises if they return
    # false. It walks over any provisioners that do not implement
    # Furnish::Protocol.
    #
    def assert_provisioner_protocol(provisioners)
      iterator = provisioners.dup
      yielding = iterator.shift

      while accepting = iterator.shift
        y_class = yielding.class
        a_class = accepting.class

        unless y_class.respond_to?(:startup_protocol)
          raise ArgumentError, "#{y_class} does not implement Furnish::Provisioner::API -- cannot continue"
        end

        unless a_class.respond_to?(:startup_protocol)
          raise ArgumentError, "#{a_class} does not implement Furnish::Provisioner::API -- cannot continue"
        end

        y_proto = y_class.startup_protocol
        a_proto = a_class.startup_protocol

        unless a_proto.requires_from(y_proto)
          raise ArgumentError, "#{accepting.class} requires information during startup that #{yielding.class} does not yield"
        end

        unless a_proto.accepts_from(y_proto)
          raise ArgumentError, "#{accepting.class} expects information during startup from #{yielding.class} that will not be delivered"
        end

        yielding = accepting
      end
    end

    #
    # Provision this group.
    #
    # Initial arguments go to the first provisioner's startup method, and then
    # the return values, if truthy, get passed to the next provisioner's
    # startup method. Any falsey value causes a RuntimeError to be raised and
    # provisioning halts, effectively creating a chain of responsibility
    # pattern.
    #
    # If a block is provided, will yield self to it for each step through the
    # group.
    #
    def startup(args={ })
      @group_state['action'] = :startup

      each_with_index do |this_prov, i|
        next unless check_recovery(this_prov, i)
        set_recovery(this_prov, i, args)

        startup_args = args

        unless args = this_prov.startup(startup_args)
          if_debug do
            puts "Could not provision #{this_prov}"
          end

          set_recovery(this_prov, i, startup_args)
          raise "Could not provision #{this_prov}"
        end

        unless args.kind_of?(Hash)
          set_recovery(this_prov, i, startup_args)
          raise ArgumentError,
            "#{this_prov.class} does not return data that can be consumed by the next provisioner"
        end

        yield self if block_given?
      end

      clean_state

      return true
    end

    #
    # Deprovision this group.
    #
    # Provisioners are run in reverse order against the shutdown method. No
    # arguments are seeded as in Furnish::ProvisionerGroup#startup. Raise
    # semantics are the same as with Furnish::ProvisionerGroup#startup.
    #
    # If a true argument is passed to this method, the raise semantics will be
    # ignored (but still logged), allowing all the provisioners to run their
    # shutdown routines. See Furnish::Scheduler#force_deprovision for
    # information on how to use this externally.
    #
    def shutdown(args={ }, force=false)
      @group_state['action'] = :shutdown

      reverse.each_with_index do |this_prov, i|
        next unless check_recovery(this_prov, i)
        set_recovery(this_prov, i, args)

        shutdown_args = args

        begin
          args = perform_deprovision(this_prov, shutdown_args) || force
        rescue Exception => e
          if_debug do
            puts "Deprovision of #{this_prov} had errors:"
            puts "#{e.message}"
          end

          unless force
            set_recovery(this_prov, i, shutdown_args)
            raise e
          end
        end

        unless args or force
          set_recovery(this_prov, i, shutdown_args)
          raise "Could not deprovision #{this_prov}"
        end
      end

      clean_state

      return true
    end

    def recover(force_deprovision=false)
      index             = @group_state['index']
      action            = @group_state['action']
      provisioner       = @group_state['provisioner']
      provisioner_args  = @group_state['provisioner_args']

      return nil unless action and provisioner and index

      result = false

      #
      # The next few lines here work around mutable state needing to happen in
      # the original provisioner, but since the one we looked up will actually
      # not be the same object, we need to deal with that by dispatching
      # recovery to the actual provisioner object in the group.
      #
      # The one stored is still useful for informational and validation
      # purposes, but the index is the ultimate authority.
      #
      offset = case action
               when :startup
                 index
               when :shutdown
                 size - 1 - index
               else
                 raise "Wtf?"
               end

      orig_prov = self[offset]

      unless orig_prov.class == provisioner.class
        raise "index and provisioner data don't seem to agree"
      end

      if orig_prov.class.respond_to?(:allows_recovery?) and orig_prov.class.allows_recovery?
        if orig_prov.recover(action, provisioner_args)
          @start_index        = index
          @start_provisioner  = orig_prov

          result = case action
                   when :startup
                     startup(provisioner_args)
                   when :shutdown
                     shutdown(provisioner_args, force_deprovision)
                   else
                     raise "Wtf?"
                   end
        end
      end

      @start_index, @start_provisioner = nil, nil

      return result # scheduler will take it from here
    end

    protected

    #
    # Similar to #clean_state, a helper for recovery tracking
    #

    def set_recovery(prov, index, args=nil)
      @group_state['provisioner'] = prov
      @group_state['index'] = index
      @group_state['provisioner_args'] = args
    end

    #
    # Returns false if this provision is to be skipped, controlled by #recover.
    #
    # Raises if something really goes wrong.
    #
    def check_recovery(prov, index)
      if @start_index and @start_provisioner
        if @start_index == index
          unless @start_provisioner.class == prov.class
            raise "Provisioner state during recovery is incorrect - something is very wrong"
          end
        end

        return index >= @start_index
      end

      return true
    end

    #
    # cleanup the group state after a group operation.
    #
    def clean_state
      @group_state.delete('index')
      @group_state.delete('action')
      @group_state.delete('provisioner')
      @group_state.delete('provisioner_args')
    end

    #
    # Just a way to simplify the deprovisioning logic with some generic logging.
    #
    def perform_deprovision(this_prov, args)
      result = this_prov.shutdown(args)
      unless result
        if_debug do
          puts "Could not deprovision group #{this_prov}."
        end
      end
      return result
    end
  end
end
