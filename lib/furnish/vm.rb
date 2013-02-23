require 'furnish/vm_group'

module Furnish
  #
  # This class mainly exists to track the run state of the Scheduler, and is kept
  # simple so that the contents can be marshalled and restored from a file.
  #
  class VM
    # the vm groups and their provisioning lists.
    attr_reader :groups
    # the dependencies that each vm group depends on
    attr_reader :dependencies
    # the set of provisioned (solved) groups
    attr_reader :provisioned
    # the set of provisioning (working) groups
    attr_reader :working
    # the set of groups waiting to be provisioned.
    attr_reader :waiters

    def initialize
      @groups        = Palsy::Map.new('vm_groups', 'provisioner_group')
      @dependencies  = Palsy::Map.new('vm_groups', 'dependency_group')
      @provisioned   = Palsy::Set.new('vm_scheduler', 'provisioned')
      @working       = Palsy::Set.new('vm_scheduler', 'working')
      @waiters       = Palsy::Set.new('vm_scheduler', 'waiters')
      @waiters_mutex = Mutex.new
    end

    def sync_waiters
      @waiters_mutex.synchronize do
        yield @waiters
      end
    end
  end
end
