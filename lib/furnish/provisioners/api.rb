require 'furnish/provisioner'

module Furnish # :nodoc:
  module Provisioner # :nodoc:
    #
    # API Interface for furnish provisioners. Ideally, you will want to inherit
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

        instance_eval { attr_accessor name }

        furnish_properties[name] = {
          :description => description,
          :type => type
        }
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
      # non-exceptional way, or a set of values for the next provisioner if
      # successful.
      #
      # The routine in this base class will raise NotImplementedError,
      # expecting you to override it in your provisioner.
      #
      def startup(*args)
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
      def shutdown
        raise NotImplementedError, "shutdown method not implemented for #{self.class.name}"
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
    end
  end
end