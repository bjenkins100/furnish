require 'furnish/provisioner'
require 'furnish/protocol'

module Furnish # :nodoc:
  module Provisioner # :nodoc:
    #
    # API base class for furnish provisioners. Ideally, you will want to inherit
    # from this and supply your overrides. Nothing in furnish expects this
    # class to be used by your provisioners, this just lets you save some
    # trouble. That said, all methods in this class are expected to be
    # implemented by your provisioner if you choose not to use it.
    #
    # The method documentation here also declares expectations on how
    # provisioners are expected to operate, so even if you don't use this
    # class, reading the documentation and knowing what's expected are
    # essential to writing a working provisioner.
    #
    # Note that all Provisioners *must* be capable of being marshalled with
    # Ruby's Marshal library. If they are unable to do this, Furnish::Scheduler
    # will not work. There are a few things such as proc/lambda in instance
    # variables, usage of the Singleton module, and singleton classes in
    # general that will interfere with Marshal's ability to work. There are
    # additional, but less important performance complications around extend
    # and refinements that will not break anything, but severely impact the
    # performance of any furnish scheduler using a provisioner that uses them.
    #
    # This class provides some basic *optional* boilerplate for:
    #
    # * initializer/constructor usage (see API.new)
    # * property management / querying (see API.furnish_property)
    # * #furnish_group_name (see Furnish::ProvisionerGroup) usage
    # * standard #report output
    # * #to_s for various ruby functions
    #
    # Additionally, "abstract" methods have been defined for provisioner
    # control methods:
    #
    # * #startup
    # * #shutdown
    #
    # Which will raise unless implemented by your subclass.
    #
    # Return values are expected to be normal for these methods:
    #
    # * #startup
    # * #shutdown
    # * #report
    #
    # And it would be wise to read the documentation on how those should be
    # written.
    #
    class API
      ##
      # The set of furnish properties for this class. Returns a hash which is
      # keyed with symbols representing the property name, and the value itself
      # is a hash which contains two additional key/value combinations, `:type`
      # and `:description`, e.g.:
      #
      #     {
      #       :my_property => {
      #         :description => "some description",
      #         :type => Object
      #       }
      #     }
      #
      # See API.furnish_property for more information.
      #
      def self.furnish_properties
        @furnish_properties ||= { }
      end

      #
      # Configure a furnish property. Used by the standard initializer on
      # API.new for parameter validation, and provides a queryable interface
      # for external consumers via API.furnish_properties, which will be
      # exposed as a class method for your provisioner class.
      #
      # The name is a symbol or will be converted to one, and will generate an
      # accessor for instances of this class. No attempt is made to type check
      # accessor writes outside of the constructor.
      #
      # The description is a string which describes what the property controls.
      # It is unused by Furnish but exists to allow external consumers the
      # ability to expose this to third parties. The default is an empty
      # string.
      #
      # The type is a class name (default Object) used for parameter checking
      # in API.new's initializer. If the value provided during construction is
      # not a kind of this class, an ArgumentError will be raised. No attempt
      # is made to deal with inner collection types ala Generics.
      #
      # Example:
      #
      #     class MyProv < API
      #       furnish_property :foo, "does a foo", Integer
      #     end
      #
      #     obj = MyProv.new(:bar => 1) # raises, no property
      #     obj = MyProv.new(:foo => "string") # raises, invalid type
      #     obj = MyProv.new(:foo => 1) # succeeds
      #
      #     obj.foo == 1
      #
      #     MyProv.furnish_properties[:foo] ==
      #         { :description => "does a foo", :type => Integer }
      #
      def self.furnish_property(name, description="", type=Object)
        name = name.to_sym unless name.kind_of?(Symbol)

        attr_accessor name

        furnish_properties[name] = {
          :description  => description,
          :type         => type
        }
      end

      #
      # Indicate whether or not this Provisioner allows recovery functions.
      # Will be used in recovery mode to determine whether or not to
      # automatically deprovision the group, or attempt to recover the group
      # provision.
      #
      # Recovery (the feature) is defaulted to false, but calling this method
      # with no arguments will turn it on (i.e., set it to true). You may also
      # provide a boolean argument if you wish to turn it off.
      #
      # Note that if you turn this on, you must also define a #recover state
      # method which implements your recovery routines. If you turn it on and
      # do not define the #recover routine, NotImplementedError will be raised
      # during recovery.
      #
      # Usage:
      #
      #     # turn it on
      #     class MyProv < API
      #       allows_recovery
      #     end
      #
      #     # turn it off explicitly
      #     class MyProv < API
      #       allows_recovery false
      #     end
      #
      #     # not specifying means it's off.
      #     class MyProv < API
      #       ...
      #     end
      #
      def self.allows_recovery(val=true)
        @allows_recovery = val
      end

      #
      # Predicate to determine if this provisioner supports recovery or not.
      #
      # Please see API.allows_recovery and #recover for more information.
      #
      def self.allows_recovery?
        @allows_recovery ||= false
        @allows_recovery
      end

      #
      # This contains the Furnish::Protocol configuration for startup (aka
      # provisioning) state execution. See API.configure_startup for more
      # information.
      #
      def self.startup_protocol
        @startup_protocol ||= Furnish::Protocol.new
      end

      #
      # configure the Furnish::Protocol for startup state execution. This
      # allows you to define constraints for your provisioner that are used at
      # scheduling time to determine whether or not the ProvisionerGroup will
      # be able to finish its provision.
      #
      # It's a bit like run-time type inference for a full provision; it just
      # tries to figure out if it'll break before it runs.
      #
      # The block provided will be instance_eval'd over a Furnish::Protocol
      # object. You can use methods like Furnish::Protocol#accepts_from_any,
      # Furnish::Protocol#requires, Furnish::Protocol#accepts,
      # Furnish::Protocol#yields to describe what it'll pass on to the next
      # provisioner or expects from the one coming before it.
      #
      # Example:
      #
      #     class MyProv < API
      #       configure_startup do
      #         requires :ip_address, "the IP address returned by the last provision", String
      #         accepts :network, "A CIDR network used by the last provision", String
      #         yields :port, "A TCP port for the service allocated by this provisioner", Integer
      #       end
      #     end
      #
      # This means:
      #
      # * An IP address has to come from the previous provisioner named "ip_address".
      # * If a network CIDR was supplied, it will be used.
      # * This provision will provide a TCP port number for whatever it makes,
      #   which the next provisioner can work with.
      #
      # See Furnish::Protocol for more information.
      #
      def self.configure_startup(&block)
        startup_protocol.configure(&block)
      end

      ##
      # The furnish_group_name is set by Furnish::ProvisionerGroup when
      # scheduling is requested via Furnish::Scheduler. It is a hint to the
      # provisioner as to what the name of the group it's in is, which can be
      # used to persist data, name things in a unique way, etc.
      attr_accessor :furnish_group_name

      #
      # Default constructor. If given arguments, must be of type Hash, keys are
      # the name of furnish properties. Raises ArgumentError if no furnish
      # property exists, or the type of the value provided is not a kind of
      # type specified in the property. See API.furnish_property for more
      # information.
      #
      # Does nothing more, not required anywhere in furnish itself -- you may
      # redefine this constructor and work completely differently wrt input and
      # behavior, or call this as a superclass initializer and then do your
      # work.
      #
      def initialize(args={})
        unless args.kind_of?(Hash)
          raise ArgumentError, "Arguments must be a kind of hash"
        end

        args.each do |k, v|
          props = self.class.furnish_properties

          if props.has_key?(k)
            if v.kind_of?(props[k][:type])
              send("#{k}=", v)
            else
              raise ArgumentError, "Value for furnish property #{k} on #{self.class.name} does not match type #{props[k][:type]}"
            end
          else
            raise ArgumentError, "Invalid argument #{k}, not a furnish property for #{self.class.name}"
          end
        end
      end

      #
      # called by Furnish::ProvisionerGroup which is itself called by
      # Furnish::Scheduler. Indicates the resource this provisioner manages is
      # to be created.
      #
      # Arguments will come from the return values of the previous
      # provisioner's startup or nothing if this is the first provisioner.
      # Return value is expected to be false if the provision failed in a
      # non-exceptional way, or a hash of values for the next provisioner if
      # successful. See Furnish::Protocol for more information of what truthy
      # values should look like.
      #
      # The routine in this base class will raise NotImplementedError,
      # expecting you to override it in your provisioner.
      #
      def startup(args={})
        raise NotImplementedError, "startup method not implemented for #{self.class.name}"
      end

      #
      # called by Furnish::ProvisionerGroup which is itself called by
      # Furnish::Scheduler. Indicates the resource this provisioner manages is
      # to be destroyed.
      #
      # No arguments accepted, returns true on success or false on
      # non-exceptional failure (which may be ignored by the scheduler).
      #
      # The routine in this base class will raise NotImplementedError,
      # expecting you to override it in your provisioner.
      #
      def shutdown(args={})
        raise NotImplementedError, "shutdown method not implemented for #{self.class.name}"
      end

      #
      # Initiate recovery. This is an optional state transition, and if
      # unavailable will assume recovery is not possible. Inheriting from this
      # class provides this and therefore will always be available. See
      # API.allows_recovery for information on how to control this feature in
      # your provisioner. If recovery is possible in your provisioner and you
      # have not defined a working recover method of your own,
      # NotImplementedError will be raised.
      #
      # recover takes two arguments, the desired state and the arguments passed
      # during the initial attempt at state transition: for example, `:startup`
      # and a hash that conforms to Furnish::Protocol definitions.
      #
      # recover is expected to return true if recovery was successful, and
      # false if it was not. If successful, the original state will be invoked
      # with its original arguments, just like it was receiving the transition
      # for the first time. Therefore, for recover to be successful, it should
      # clean up any work the state has already done.
      #
      # In the event recovery is not possible (the recover routine returns
      # false), depending on how the scheduler is configured, the group will
      # either deprovision itself or halt the scheduler again, forcing the code
      # to handle recovery manually.
      #
      # Example: a provisioner for a security group crashes during running
      # startup. The scheduler pauses, and is instructed to go into recovery
      # mode. The method #recover is called, which then cleans up the security
      # group attempted to be created (if it does not exist, that's fine too).
      # Then, it returns true. Then the scheduler will retry the startup
      # routine for the security group, which will attempt the same thing as if
      # it has never tried to begin with.
      #
      def recover(state, args)
        if self.class.allows_recovery?
          raise NotImplementedError, "#{self.class} allows recovery but no #recover method was defined."
        else
          return false
        end
      end

      #
      # returns an array of strings with some high-level information about the
      # provision. Intended for UI tools that need to query a provisioner group
      # about the resources it manages.
      #
      # Default is to return the provisioner group name or "unknown" if it is
      # not set yet.
      #
      def report
        [furnish_group_name || "unknown"]
      end

      #
      # Used by various logging pieces throughout furnish and Ruby itself.
      #
      # Default is to return "group name[provisioner class name]" where group
      # name will be "unknown" if not set.
      #
      # For example, in a group called 'test1', and the provisioner class is
      # Furnish::Provisioner::EC2:
      #
      #     "test1[Furnish::Provisioner::EC2]"
      #
      def to_s
        name = furnish_group_name || "unknown"
        "#{name}[#{self.class.name}]"
      end

      alias inspect to_s # FIXME make this less stupid later

      def ==(other)
        self.hash == other.hash
      end

      def hash
        Marshal.dump(
          instance_variables.sort.map do |x|
            y = instance_variable_get(x)
            y.kind_of?(String) ?
              y.encode("UTF-8", :invalid => :replace, :replace => "?".chr) :
              y
          end +
          [self.class]
        )
      end
    end
  end
end
