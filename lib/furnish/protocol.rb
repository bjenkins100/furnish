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
      not_configurable

      return true unless protocol

      yp = protocol[:yields]
      rp = self[:requires]

      return true   if rp.keys.empty?
      return false  unless (yp.keys & rp.keys).sort == rp.keys.sort

      return true
    end

    def accepts_from(protocol)
      not_configurable

      return true unless protocol

      yp = protocol[:yields]
      ap = self[:accepts]

      if yp.keys.empty? or ap.keys.empty? or (yp.keys & ap.keys).empty?
        return self[:accepts_from_any]
      end

      return true
    end

    VALIDATOR_NAMES.each do |vname|
      instance_eval <<-EOF
        def #{vname}(name, description='', type=Object)
          build(#{vname.inspect}, name, description, type=Object)
        end
      EOF
    end

    private

    def not_configurable
      if @configuring
        raise RuntimeError, "cannot use this method during configuration"
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
