require 'furnish/provisioner'

module Furnish
  module Provisioner
    class API
      attr_accessor :furnish_group_name

      def initialize(args)
        unless args.kind_of?(Hash)
          raise ArgumentError, "Arguments must be a kind of hash"
        end

        args.each do |k, v|
          send("#{k}=", v)
        end
      end

      def startup(*args)
        raise "startup method not implemented for #{self.class.name}"
      end

      def shutdown
        raise "shutdown method not implemented for #{self.class.name}"
      end

      def report
        [furnish_group_name || "unknown"]
      end

      def to_s
        name = furnish_group_name || "unknown"
        "#{name}[#{self.class.name}]"
      end
    end
  end
end
