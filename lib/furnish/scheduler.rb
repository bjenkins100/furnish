require 'timeout'
require 'furnish/vm'
require 'furnish/logger'
require 'furnish/provisioner_group'

module Furnish
  #
  # This is a scheduler for provisioners. It can run in parallel or serial mode,
  # and is dependency-based, that is, it will only schedule items for execution
  # which have all their dependencies satisfied and items that haven't will wait
  # to execute until that happens.
  #
  class Scheduler

    include Furnish::Logger::Mixins

    #
    # Access the VM object.
    #
    attr_reader :vm

    #
    # Turn serial mode on (off by default). This forces the scheduler to execute
    # every provision in order, even if it could handle multiple provisions at
    # the same time.
    #
    attr_accessor :serial

    ##
    #
    # Ignore exceptions while deprovisioning. Default is false.
    #
    attr_accessor :force_deprovision

    ##
    #
    # When true, calling #run or #recover also installs a SIGINFO (Ctrl+T in the
    # terminal on macs) and SIGUSR2 handler which can be used to get
    # information on the status of what's solved and what's working.
    #
    # Default is true.
    #

    attr_accessor :signal_handler

    #
    # Instantiate the Scheduler.
    #
    def initialize
      @force_deprovision  = false
      @solved_mutex       = Mutex.new
      @serial             = false
      @solver_thread      = nil
      @working_threads    = { }
      @queue              = Queue.new
      @vm                 = Furnish::VM.new
      @signal_handler     = true
    end

    #
    # Ask the scheduler if it's running. Returns nil in serial mode.
    #
    # If there's an exception waiting and the scheduler has stopped, it will be
    # raised here.
    #
    def running?
      return nil if @serial
      return nil unless @solver_thread
      if @solver_thread.alive?
        return true
      else
        # XXX if there's an exception to be raised, it'll happen here.
        @solver_thread.join
        return nil
      end
    end

    #
    # Schedule a group of VMs for provision. This takes a group name, which is a
    # string, an array of provisioner objects, and a list of string dependencies.
    # If anything in the dependencies list hasn't been pre-declared, it refuses
    # to continue.
    #
    # This method will return nil if the server group is already provisioned.
    #
    def schedule_provision(group_name, provisioners, dependencies=[])
      group = Furnish::ProvisionerGroup.new(provisioners, group_name, dependencies)
      schedule_provisioner_group(group)
    end

    alias s schedule_provision
    alias sched schedule_provision

    #
    # Schedule a provision with a Furnish::ProvisionerGroup. Works exactly like
    # Furnish::Scheduler#schedule_provision otherwise.
    #
    def schedule_provisioner_group(group)
      return nil if vm.groups[group.name]

      vm.groups[group.name] = group

      unless group.dependencies.all? { |x| vm.groups.has_key?(x) }
        raise "One of your dependencies for #{group.name} has not been pre-declared. Cannot continue"
      end

      vm.dependencies[group.name] = group.dependencies

      vm.sync_waiters do |waiters|
        waiters.add(group.name)
      end
    end

    alias << schedule_provisioner_group

    #
    # Sleep until this list of dependencies are resolved. In parallel mode, will
    # raise if an exception occurred while waiting for these resources. In
    # serial mode, wait_for just returns nil.
    #
    def wait_for(*dependencies)
      return nil if @serial
      return nil if dependencies.empty?

      dep_set = Set[*dependencies]

      until dep_set & vm.solved == dep_set
        sleep 0.1
        @solver_thread.join unless @solver_thread.alive?
      end
    end

    #
    # Start the scheduler. In serial mode this call will block until the whole
    # dependency graph is satisfied, or one of the provisions fails, at which
    # point an exception will be raised. In parallel mode, this call completes
    # immediately, and you should use #wait_for to control main thread flow,
    # and #running? and #stop to control and monitor the threads this class
    # manages.
    #
    def run
      # short circuit if we're not serial and already running
      return if running?

      install_handler if signal_handler

      if @serial
        service_resolved_waiters
        queue_loop
      else
        @solver_thread = Thread.new do
          with_timeout(false) { service_resolved_waiters }
          queue_loop
        end
      end
    end

    #
    # Instructs the scheduler to stop. Note that this is not an interrupt, and
    # the queue will still be exhausted before terminating.
    #
    # It is a good idea to check #running? before calling this to ensure the
    # scheduler did not halt with an exception.
    #
    def stop
      if @serial
        @queue << nil
      else
        @working_threads.values.map { |v| v.join rescue nil }
        if @solver_thread and @solver_thread.alive?
          @queue << nil
          sleep 0.1 until @queue.empty?
          @solver_thread.kill
        end

        @solver_thread = nil
      end
    end

    #
    # Teardown a single group -- modifies the solved formula. Be careful to
    # resupply dependencies if you use this, as nothing will resolve until you
    # resupply it.
    #
    # This takes an optional argument to wait for the group to be solved before
    # attempting to tear it down. Setting this to false effectively says, "I know
    # what I'm doing", and you should feel bad if you file an issue because you
    # supplied it.
    #
    # If #force_provision is true, failed shutdowns from provisioners will not
    # halt the deprovisioning process.
    #
    def teardown_group(group_name, wait=true)
      wait_for(group_name) if wait

      dependent_items = vm.dependencies.partition { |k,v| v.include?(group_name) }.first.map(&:first)

      if_debug do
        if dependent_items.length > 0
          puts "Trying to terminate #{group_name}, found #{dependent_items.inspect} depending on it"
        end
      end

      @solved_mutex.synchronize do
        dependent_and_working = @working_threads.keys & dependent_items

        if dependent_and_working.count > 0
          if_debug do
            puts "#{dependent_and_working.inspect} are depending on #{group_name}, which you are trying to deprovision."
            puts "We can't resolve this problem for you, and future converges may fail during this run that would otherwise work."
            puts "Consider using wait_for to better control the dependencies, or turning serial provisioning on."
          end
        end

        deprovision_group(group_name)
      end

    end

    #
    # Instruct all provisioners except ones in the exception list to tear down.
    # Calls #stop as its first action.
    #
    # This is always done serially. For sanity.
    #
    # If #force_provision is true, failed shutdowns from provisioners will not
    # halt the deprovisioning process.
    #
    def teardown(exceptions=[])
      stop

      (vm.groups.keys.to_set - exceptions.to_set).each do |group_name|
        deprovision_group(group_name) # clean this after everything finishes
      end
    end

    #
    # Performs the deprovision of a group by replaying its provision strategy
    # backwards and applying the #shutdown method instead of the #startup method.
    # Removes it from the various state tables if true is set as the second
    # argument, which is the default.
    #
    # While this is a part of the public API, you should probably use #teardown
    # or #teardown_group instead of this method, as they have better error
    # handling and semantics. This "just does it".
    #
    def deprovision_group(group_name, clean_state=true)
      shutdown(group_name)
      delete_group(group_name) if clean_state
    end

    #--
    #
    # END OF PUBLIC API
    #
    #++

    protected

    #
    # Helper method for scheduling. Wraps items in a timeout and immediately
    # checks all running workers for exceptions, which are immediately bubbled up
    # if there are any. If do_loop is true, it will retry the timeout.
    #
    def with_timeout(do_loop=true)
      Timeout.timeout(1) do
        dead_working = @working_threads.values.reject(&:alive?)
        if dead_working.size > 0
          dead_working.map(&:join)
        end

        yield
      end
    rescue TimeoutError
      retry if do_loop
    end

    #
    # Consume the queue. Runs until a nil enters the queue, unless in serial
    # mode, where it will terminate when the queue is empty.
    #
    def queue_loop
      run = true

      while run
        service_resolved_waiters

        ready = []

        if @queue.empty?
          if @serial
            return
          else
            with_timeout do
              # this is where most of the execution time is spent, so ensure
              # waiters get considered here.
              service_resolved_waiters
              ready << @queue.shift
            end
          end
        end

        while !@queue.empty?
          ready << @queue.shift
        end

        ready.each do |r|
          if r
            @solved_mutex.synchronize do
              vm.solved.add(r)
              @working_threads.delete(r)
              vm.working.delete(r)
            end
          else
            run = false
          end
        end
      end
    end

    #
    # Helper method to manage waiters based on solved dependencies.
    #
    def resolve_waiters
      vm.sync_waiters do |waiters|
        waiters.replace(waiters.to_set - (@working_threads.keys.to_set + vm.solved.to_set))
      end
    end

    #
    # Predicate to determine all of a groups dependencies are in the solved set.
    #
    def dependencies_solved?(group_name)
      (vm.solved.to_set & vm.dependencies[group_name]) == vm.dependencies[group_name]
    end

    #
    # Fetch the ProvisionerGroup and start it.
    #
    def startup(group_name)
      provisioner = vm.groups[group_name]

      # FIXME maybe a way to specify initial args?
      args = nil

      provisioner.startup do |this_prov|
        vm.groups[group_name] = this_prov
      end

      vm.groups[group_name] = provisioner

      @queue << group_name
    end

    #
    # Similar to #startup -- just a shim to talk to a specific ProvisionerGroup
    #
    def shutdown(group_name)
      provisioner = vm.groups[group_name]

      # if we can't find the provisioner, we probably got asked to clean up
      # something we never scheduled. Just ignore that.
      if provisioner and can_deprovision?(group_name)
        provisioner.shutdown(@force_deprovision)
      end
    end

    #
    # This method determines what 'waiters', or provisioners that cannot
    # provision yet because of unresolved dependencies, can be executed.
    #
    def service_resolved_waiters
      resolve_waiters

      vm.sync_waiters do |waiters|
        waiters.each do |group_name|
          if dependencies_solved?(group_name)
            if_debug do
              puts "Provisioning #{group_name}"
            end

            vm.working.add(group_name)

            if @serial
              # HACK: just give the working check something that will always work.
              #       Probably should just mock it.
              @working_threads[group_name] = Thread.new { sleep }
              startup(group_name)
            else
              @working_threads[group_name] = Thread.new { startup(group_name) }
            end
          end
        end
      end
    end

    #
    # Predicate to determine if a provisioner group can be shutdown.
    #
    def can_deprovision?(group_name)
      ((vm.solved.to_set + vm.working.to_set).include?(group_name) or @force_deprovision)
    end

    #
    # Wipes the ProvisionerGroup out of the scheduler's state, and terminates
    # any threads managing it.
    #
    def delete_group(group_name)
      vm.solved.delete(group_name)
      vm.sync_waiters do |waiters|
        waiters.delete(group_name)
      end
      @working_threads[group_name].kill rescue nil
      @working_threads.delete(group_name)
      vm.working.delete(group_name)
      vm.dependencies.delete(group_name)
      vm.groups.delete(group_name)
    end

    def install_handler
      handler = lambda do |*args|
        # XXX See Palsy#with_t and Palsy#no_lock for why this is necessary.
        Palsy.instance.no_lock do
          Furnish.logger.puts ["solved:", vm.solved.to_a].inspect
          Furnish.logger.puts ["working:", vm.working.to_a].inspect
          Furnish.logger.puts ["waiting:", vm.waiters.to_a].inspect
          Furnish.logger.puts ["provisioning:", vm.working.to_a.map { |w| [w, vm.groups[w].group_state['action'], groups[w].group_state['provisioner']] }]
        end
      end

      %w[USR2 INFO].each { |sig| trap(sig, &handler) if Signal.list[sig] }
    end
  end
end
