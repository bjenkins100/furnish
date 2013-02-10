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

    def initialize
      @groups        = Furnish::VMGroup.new('vm_groups', false)
      @dependencies  = Furnish::VMGroup.new('vm_dependencies', true)
      @provisioned   = Palsy::Set.new('vm_scheduler', 'provisioned')
      @working       = Palsy::Set.new('vm_scheduler', 'working')
    end
  end
end
