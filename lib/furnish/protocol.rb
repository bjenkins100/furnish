module Furnish # :nodoc:
  #
  # Furnish::Protocol implements a validating protocol for state transitions.
  # It is an optional feature and not necessary for using Furnish.
  #
  # A Furnish::ProvisionerGroup looks like this:
  #
  # thing_a -> thing_b -> thing_c
  #
  # Where these things are furnish provisioners. When the scheduler says it's
  # ready to provision this group, it executes thing_a's startup routine,
  # passes its results to thing_b's startup routine, and then thing_b's startup
  # routine passes its things to thing_c's startup routine.
  #
  # Presuming this all succeeds (and returns truthy values), the group is
  # marked as 'solved', the scheduler considers it finished and will ignore
  # future requests to provision it again. It also will start working on
  # anything that depends on its solved state.
  #
  # A problem is that you have to know ahead of time how a, b, and c interact
  # for this to be successful. For example, you can't allocate an EC2 security
  # group, than an instance, then a VPC, and expect the security group and
  # instance to live in that VPC. It's not only out of order, but the security
  # group doesn't know enough at the time it runs to leverage the VPC, because
  # the VPC doesn't exist yet.
  #
  # Furnish::Protocol lets you describe what each provisioner requires, what it
  # accepts, and what it yields, so that analysis can be performed at scheduler
  # time (when it's configured) instead of provisioning time (when it actually
  # runs). This surfaces issues quicker and has some additional advantages for
  # interfaces where users may not have full visibility into what the
  # provisioners do (such as closed source provisioners, or inadequately
  # documented ones).
  #
  # Here's a description of how this logic works for two adjacent provisioners
  # in the group, a and b:
  #
  # * if Provisioner A and Provisioner B implement Furnish::Protocol
  #   * if B requires anything, and A yields all of it with the proper types
  #     * if B accepts anything, and A yields any of it with the proper types
  #       * success
  #     * else failure
  #   * if B accepts anything, and A yields any of it with the proper types
  #     * success
  #   * if B has #accepts_from_any set to true
  #     * success
  #   * if B accepts nothing
  #     * success
  #   * else failure
  # * else success
  #
  # Provisioners at the head and tail do not get subject to acceptance tests
  # because there's nothing to yield, or nothing to accept what is yielded.
  #
  class Protocol

    ##
    # :method:
    # :call-seq:
    #   requires(name)
    #   requires(name, description)
    #   requires(name, description, type)
    #
    # Specifies a requirement. The name is the key of the requirement, the
    # description is a text explanantion of what the requirement is used for,
    # for informational purposes. The name and type (which is a class) are
    # compared to #yields in #requires_from and the logic behind that is
    # explained in Furnish::Protocol.
    #
    # See Furnish::Provisioner::API.configure_startup for a usage example.
    #

    ##
    # :method:
    # :call-seq:
    #   accepts(name)
    #   accepts(name, description)
    #   accepts(name, description, type)
    #
    # Specifies acceptance critieria. While #requires is "all", this is "any",
    # and acceptance is further predicated by the #accepts_from_any status if
    # acceptance checks fail. The attributes set here will be used in
    # #accepts_from to validate against another provisioner.
    #
    # See the logic explanation in Furnish::Protocol for more information.
    #
    # See Furnish::Provisioner::API.configure_startup for a usage example.
    #

    ##
    # :method:
    # :call-seq:
    #   yields(name)
    #   yields(name, description)
    #   yields(name, description, type)
    #
    # Specifies what the provisioner is expected to yield. This is the producer
    # for the consumer counterparts #requires and #accepts. The configuration
    # made here will be used in both #requires_from and #accepts_from for
    # determining if two provisioners can talk to each other.
    #
    # See the logic explanation in Furnish::Protocol for more information.
    #
    # See Furnish::Provisioner::API.configure_startup for a usage example.
    #

    VALIDATOR_NAMES = [:requires, :accepts, :yields] # :nodoc:

    #
    # Construct a Furnish::Protocol object.
    #
    def initialize
      @hash = Hash[VALIDATOR_NAMES.map { |n| [n, { }] }]
      @configuring = false
    end

    #
    # This runs the block given instance evaled against the current
    # Furnish::Protocol object. It is used by Furnish::Provisioner::API's
    # syntax sugar.
    #
    # Additionally it sets a simple lock to ensure the assertions
    # Furnish::Protocol provides cannot be used during configuration time, like
    # #accept_from and #requires_from.
    #
    def configure(&block)
      @configuring = true
      instance_eval(&block)
      @configuring = false
    end

    #
    # Allow #accepts_from to completely mismatch with yields from a compared
    # provisioner and still succeed. Use with caution.
    #
    # See the logic discussion in Furnish::Protocol for a deeper explanation.
    #
    def accepts_from_any(val)
      @hash[:accepts_from_any] = val
    end

    #
    # look up a rule set -- generally should not be used by consumers.
    #
    def [](key)
      @hash[key]
    end

    #
    # For a passed Furnish::Protocol object, ensures that this protocol object
    # satisfies its requirements based on what it yields.
    #
    # See the logic discussion in Furnish::Protocol for a deeper explanation.
    #
    def requires_from(protocol)
      not_configurable(__method__)

      return true unless protocol

      yp = protocol[:yields]
      rp = self[:requires]

      rp.keys.empty? ||
        (
          (yp.keys & rp.keys).sort == rp.keys.sort &&
          rp.keys.all? { |k| rp[k][:type].ancestors.include?(yp[k][:type]) }
        )
    end

    #
    # For a passed Furnish::Protocol object, ensures that at least one thing
    # this protocol object accepts is satisfied by what that Furnish::Protocol
    # object yields.
    #
    # See the logic discussion in Furnish::Protocol for a deeper explanation.
    #
    def accepts_from(protocol)
      not_configurable(__method__)

      return true unless protocol

      yp = protocol[:yields]
      ap = self[:accepts]

      return true if ap.keys.empty?

      if (yp.keys & ap.keys).empty?
        return self[:accepts_from_any]
      end

      return (yp.keys & ap.keys).all? { |k| ap[k][:type].ancestors.include?(yp[k][:type]) }
    end

    VALIDATOR_NAMES.each do |vname|
      class_eval <<-EOF
        def #{vname}(name, description='', type=Object)
          name = name.to_sym unless name.kind_of?(Symbol)
          build(#{vname.inspect}, name, description, type)
        end
      EOF
    end

    private

    #
    # Just a little "pragma" to ensure certain methods cannot be used in
    # #configure.
    #
    def not_configurable(meth_name)
      if @configuring
        raise RuntimeError, "cannot use method '#{meth_name}' during protocol configuration"
      end
    end

    #
    # Metaprogramming shim, delegated to by #requires, #accepts and #yields.
    # Fills out the tables when classes use those methods.
    #
    def build(vtype, name, description, type)
      @hash[vtype][name] = {
        :description => description,
        :type        => type
      }
    end
  end
end
