require 'furnish/provisioners/api'

module Furnish # :nodoc:
  module Provisioner # :nodoc:
    #
    # The VM provisioner API (which inherits from Furnish::Provisioner::API)
    # just adds a few convenience functions and a tracking database for VM
    # work. This makes it easy to get the data back you need and an easy,
    # consistent way to stuff it away when you have data to store.
    #
    # See the methods themselves for more information.
    #
    class VM < API
      #
      # Our database, which won't be available until the provisioner is added
      # to a ProvisionerGroup.
      #
      attr_reader :vm

      #
      # Hook required by Furnish::ProvisionerGroup#run_add_hook. See
      # Furnish::Provisioner::API#added_to_group for more information.
      #
      def added_to_group
        @vm = Palsy::Map.new(self.class.name.gsub(/::/, '_').downcase + "_vms", furnish_group_name)
      end

      #
      # Add a vm. Takes a name (String) and metadata (Hash).
      #
      def add_vm(name, metadata)
        unless vm
          raise "Cannot add machine '#{name}' to ungrouped provisioner"
        end

        unless metadata.kind_of?(Hash)
          raise ArgumentError, "Metadata must be a kind of Hash!"
        end

        vm[name] = metadata
      end

      #
      # Delete a VM. Takes a name (String).
      #
      def remove_vm(name)
        unless vm
          raise "Cannot delete machine '#{name}' from ungrouped provisioner"
        end

        vm.delete(name)
      end

      #
      # List the VMs. If the provisioner is not named (a part of a
      # Furnish::ProvisionerGroup), will return an empty array.
      #
      def list_vms
        return [] unless vm
        return vm.keys
      end
    end
  end
end
