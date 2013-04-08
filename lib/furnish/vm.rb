module Furnish
  #
  # This class mainly exists to track the run state of the Scheduler, and is kept
  # simple. The attributes delegate to Palsy instances.
  #
  class VM
    # the vm groups and their provisioning lists.
    attr_reader :groups
    # the dependencies that each vm group depends on
    attr_reader :dependencies
    # the set of provisioned (solved) groups
    attr_reader :solved
    # the set of provisioning (working) groups
    attr_reader :working
    # the set of groups waiting to be provisioned.
    attr_reader :waiters
    # the set of groups that need recovery, and the exceptions they threw (if any)
    attr_reader :need_recovery

    #
    # Create a new VM object. Should only happen in the Scheduler.
    #
    def initialize
      @groups        = Palsy::Map.new('vm_groups', 'provisioner_group')
      @dependencies  = Palsy::Map.new('vm_groups', 'dependency_group')
      @need_recovery = Palsy::Map.new('vm_groups', 'need_recovery')
      @solved        = Palsy::Set.new('vm_scheduler', 'provisioned')
      @working       = Palsy::Set.new('vm_scheduler', 'working')
      @waiters       = Palsy::Set.new('vm_scheduler', 'waiters')
      @waiters_mutex = Mutex.new
    end

    #
    # Helper to deal with waiters in a synchronous way.
    #
    def sync_waiters
      @waiters_mutex.synchronize do
        yield @waiters
      end
    end
  end
end
