require 'furnish/provisioners/api'

module Furnish # :nodoc:
  module Provisioner # :nodoc:
    class VM < API
      attr_reader :vm

      def added_to_group
        @vm = Palsy::Map.new(self.class.name.gsub(/::/, '_').downcase + "_vms", furnish_group_name)
      end

      def add_vm(name, metadata)
        unless vm
          raise "Cannot add machine '#{name}' to ungrouped provisioner"
        end

        unless metadata.kind_of?(Hash)
          raise ArgumentError, "Metadata must be a kind of Hash!"
        end

        vm[name] = metadata
      end

      def remove_vm(name)
        unless vm
          raise "Cannot delete machine '#{name}' from ungrouped provisioner"
        end

        vm.delete(name)
      end

      def list_vms
        return [] unless vm
        return vm.keys
      end
    end
  end
end
