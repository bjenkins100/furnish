module Furnish
  class Protocol
    VALIDATOR_NAMES = [:requires, :accepts, :yields] # :nodoc:

    def initialize
      @hash = Hash[VALIDATOR_NAMES.map { |n| [n, { }] }]
      @configuring = false
    end

    def configure(&block)
      @configuring = true
      instance_eval(&block)
      @configuring = false
    end

    def accepts_from_any(val)
      @hash[:accepts_from_any] = val
    end

    def [](key)
      @hash[key]
    end

    def requires_from(protocol)
      not_configurable(__method__)

      return true unless protocol

      yp = protocol[:yields]
      rp = self[:requires]

      rp.keys.empty? || (yp.keys & rp.keys).sort == rp.keys.sort
    end

    def accepts_from(protocol)
      not_configurable(__method__)

      return true unless protocol

      yp = protocol[:yields]
      ap = self[:accepts]

      if yp.keys.empty? or ap.keys.empty? or (yp.keys & ap.keys).empty?
        return self[:accepts_from_any]
      end

      return true
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

    def not_configurable(meth_name)
      if @configuring
        raise RuntimeError, "cannot use method '#{meth_name}' during protocol configuration"
      end
    end

    def build(vtype, name, description, type)
      @hash[vtype][name] = {
        :description => description,
        :type        => type
      }
    end
  end
end
