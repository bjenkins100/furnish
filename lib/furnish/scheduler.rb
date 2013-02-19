require 'timeout'
require 'furnish/vm'
require 'furnish/logger'

module Furnish
  #
  # This is a scheduler for provisioners. It can run in parallel or serial mode,
  # and is dependency-based, that is, it will only schedule items for execution
  # which have all their dependencies satisfied and items that haven't will wait
  # to execute until that happens.
  #
  class Scheduler

    ##
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

    def initialize
      @force_deprovision  = false
      @solved_mutex       = Mutex.new
      @serial             = false
      @solver_thread      = nil
      @working_threads    = { }
      @queue              = Queue.new
      @vm                 = Furnish::VM.new
    end

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

    def if_debug(*args, &block)
      Furnish.logger.if_debug(*args, &block)
    end

    #
    # Helper to assist with dealing with a VM object
    #
    def solved
      @vm.provisioned
    end

    #
    # Helper to assist with dealing with a VM object
    #
    def vm_groups
      @vm.groups
    end

    #
    # Helper to assist with dealing with a VM object
    #
    def vm_dependencies
      @vm.dependencies
    end

    #
    # Helper to assist with dealing with a VM object
    #
    def vm_working
      @vm.working
    end

    #
    # Helper to assist with dealing with a VM object
    #
    def vm_waiters
      @vm.waiters
    end

    #
    # Helper to assist with dealing with a VM object
    #
    def sync_waiters(&block)
      @vm.sync_waiters(&block)
    end

    #
    # Schedule a group of VMs for provision. This takes a group name, which is a
    # string, an array of provisioner objects, and a list of string dependencies.
    # If anything in the dependencies list hasn't been pre-declared, it refuses
    # to continue.
    #
    # This method will return nil if the server group is already provisioned.
    #
    def schedule_provision(group_name, provisioner, dependencies=[])
      return nil if vm_groups[group_name]
      provisioner = [provisioner] unless provisioner.kind_of?(Array)
      provisioner.each { |x| x.name = group_name }
      vm_groups[group_name] = provisioner

      unless dependencies.all? { |x| vm_groups.has_key?(x) }
        raise "One of your dependencies for #{group_name} has not been pre-declared. Cannot continue"
      end

      vm_dependencies[group_name] = dependencies.to_set
      sync_waiters do |waiters|
        waiters.add(group_name)
      end
    end

    #
    # Sleep until this list of dependencies are resolved. In parallel mode, will
    # raise if an exception occurred while waiting for these resources. In
    # serial mode, wait_for just returns nil.
    #
    def wait_for(*dependencies)
      return nil if @serial
      return nil if dependencies.empty?

      dep_set = dependencies.to_set

      until dep_set & solved == dep_set
        sleep 0.1
        @solver_thread.join unless @solver_thread.alive?
      end
    end

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
    # Start the scheduler. In serial mode this call will block until the whole
    # dependency graph is satisfied, or one of the provisions fails, at which
    # point an exception will be raised. In parallel mode, this call completes
    # immediately, and you should use #wait_for to control main thread flow.
    #
    # This call also installs a SIGINFO (Ctrl+T in the terminal on macs) and
    # SIGUSR2 handler which can be used to get information on the status of
    # what's solved and what's working.
    #
    # Immediately returns if in threaded mode and the solver is already running.
    #
    def run(install_handler=true)
      # short circuit if we're not serial and already running
      return if @solver_thread and !@serial

      if install_handler
        handler = lambda do |*args|
          Furnish.logger.puts ["solved:", solved.to_a].inspect
          Furnish.logger.puts ["working:", vm_working.to_a].inspect
          Furnish.logger.puts ["waiting:", vm_waiters.to_a].inspect
        end

        %w[USR2 INFO].each { |sig| trap(sig, &handler) if Signal.list[sig] }
      end

      queue_runner = lambda do
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
                solved.add(r)
                @working_threads.delete(r)
                vm_working.delete(r)
              end
            else
              run = false
            end
          end
        end
      end

      if @serial
        service_resolved_waiters
        queue_runner.call
      else
        @solver_thread = Thread.new do
          with_timeout(false) { service_resolved_waiters }
          queue_runner.call
        end
      end
    end

    #
    # Instructs the scheduler to stop. Note that this is not an interrupt, and
    # the queue will still be exhausted before terminating.
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

    def resolve_waiters
      sync_waiters do |waiters|
        waiters.replace(waiters.to_set - (@working_threads.keys.to_set + solved.to_set))
      end
    end

    def dependencies_solved?(group_name)
      (solved.to_set & vm_dependencies[group_name]).to_a == vm_dependencies[group_name]
    end

    def startup(group_name)
      provisioner = vm_groups[group_name]

      # FIXME maybe a way to specify initial args?
      args = nil
      provisioner.each do |this_prov|
        unless args = this_prov.startup(args)
          if_debug do
            puts "Could not provision #{group_name} with provisioner #{this_prov.class.name}"
          end

          raise "Could not provision #{group_name} with provisioner #{this_prov.class.name}"
        end
      end
      @queue << group_name
    end

    #
    # This method determines what 'waiters', or provisioners that cannot
    # provision yet because of unresolved dependencies, can be executed.
    #
    def service_resolved_waiters
      resolve_waiters

      sync_waiters do |waiters|
        waiters.each do |group_name|
          if dependencies_solved?(group_name)
            if_debug do
              puts "Provisioning #{group_name}"
            end

            vm_working.add(group_name)

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
    # Teardown a single group -- modifies the solved formula. Be careful to
    # resupply dependencies if you use this, as nothing will resolve until you
    # resupply it.
    #
    # This takes an optional argument to wait for the group to be solved before
    # attempting to tear it down. Setting this to false effectively says, "I know
    # what I'm doing", and you should feel bad if you file an issue because you
    # supplied it.
    #

    def teardown_group(group_name, wait=true)
      wait_for(group_name) if wait

      dependent_items = vm_dependencies.partition { |k,v| v.include?(group_name) }.first.map(&:first)

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

    def can_deprovision?(group_name)
      ((solved.to_set + vm_working.to_set).include?(group_name) or @force_deprovision)
    end

    def perform_deprovision(this_prov)
      result = this_prov.shutdown
      unless result
        if_debug do
          puts "Could not deprovision group #{this_prov.name}."
        end
      end
      return result
    end

    def shutdown(group_name)
      provisioner = vm_groups[group_name]

      # if we can't find the provisioner, we probably got asked to clean up
      # something we never scheduled. Just ignore that.
      if provisioner and can_deprovision?(group_name)
        if_debug do
          puts "Attempting to deprovision group #{group_name}"
        end

        provisioner.reverse.each do |this_prov|
          begin
            unless perform_deprovision(this_prov) or @force_deprovision
              raise "Could not deprovision #{group_name}/#{this_prov.inspect}"
            end
          rescue Exception => e
            if @force_deprovision
              if_debug do
                puts "Deprovision #{this_prov.class.name}/#{group_name} had errors:"
                puts "#{e.message}"
              end
            else
              raise e
            end
          end
        end
      end
    end

    def delete_group(group_name)
      solved.delete(group_name)
      sync_waiters do |waiters|
        waiters.delete(group_name)
      end
      @working_threads[group_name].kill rescue nil
      @working_threads.delete(group_name)
      vm_working.delete(group_name)
      vm_dependencies.delete(group_name)
      vm_groups.delete(group_name)
    end

    #
    # Performs the deprovision of a group by replaying its provision strategy
    # backwards and applying the #shutdown method instead of the #startup method.
    # Removes it from the various state tables if true is set as the second
    # argument, which is the default.
    #
    def deprovision_group(group_name, clean_state=true)
      shutdown(group_name)
      delete_group(group_name) if clean_state
    end

    #
    # Instruct all provisioners except ones in the exception list to tear down.
    # Calls #stop as its first action.
    #
    # This is always done serially. For sanity.
    #
    def teardown(exceptions=[])
      stop

      (vm_groups.keys.to_set - exceptions.to_set).each do |group_name|
        deprovision_group(group_name) # clean this after everything finishes
      end
    end
  end
end
