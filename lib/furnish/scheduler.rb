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

    #
    # Constructor. If the first argument is true, will install an `at_exit` hook
    # to write out the VM and IP databases.
    #
    def initialize
      @force_deprovision  = false
      @solved_mutex       = Mutex.new
      @waiters_mutex      = Mutex.new
      @serial             = false
      @solver_thread      = nil
      @working            = { }
      @waiters            = Palsy::Set.new('vm_scheduler', 'waiters')
      @queue              = Queue.new
      @vm                 = Furnish::VM.new
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
      @waiters_mutex.synchronize do
        @waiters.add(group_name)
      end
    end

    #
    # Sleep until this list of dependencies are resolved. In parallel mode, will
    # raise if an exeception occurred while waiting for these resources. In
    # serial mode, wait_for just returns nil.
    #
    def wait_for(*dependencies)
      return nil if @serial
      return nil if dependencies.empty?

      dep_set = dependencies.to_set
      until dep_set & solved == dep_set
        sleep 1
        @solver_thread.join unless @solver_thread.alive?
      end
    end

    #
    # Helper method for scheduling. Wraps items in a timeout and immediately
    # checks all running workers for exceptions, which are immediately bubbled up
    # if there are any. If do_loop is true, it will retry the timeout.
    #
    def with_timeout(do_loop=true)
      Timeout.timeout(10) do
        dead_working = @working.values.reject(&:alive?)
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
    def run
      # short circuit if we're not serial and already running
      return if @solver_thread and !@serial

      handler = lambda do |*args|
        p ["solved:", solved.to_a]
        p ["working:", vm_working.to_a]
        p ["waiting:", @waiters.to_a]
      end

      %w[USR2 INFO].each { |sig| trap(sig, &handler) if Signal.list[sig] }

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
                @working.delete(r)
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

        # we depend on at_exit hooks being fired, and Thread#abort_on_exception
        # doesn't fire them. This solution bubbles up the exceptions in a similar
        # fashion without actually sacrificing the at_exit functionality.
        Thread.new do
          begin
            @solver_thread.join
          rescue Exception => e
            $stderr.puts "Solver thread encountered an exception:"
            $stderr.puts "#{e.class.name}: #{e.message}"
            $stderr.puts e.backtrace.join("\n")
            Kernel.exit 1
          end
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
        @working.values.map { |v| v.join rescue nil }
        @queue << nil
        @solver_thread.join rescue nil
      end
    end

    #
    # This method determines what 'waiters', or provisioners that cannot
    # provision yet because of unresolved dependencies, can be executed.
    #
    def service_resolved_waiters
      @waiters_mutex.synchronize do
        @waiters.replace(@waiters.to_set - (@working.keys.to_set + solved))
      end

      waiter_iteration = lambda do
        @waiters.each do |group_name|
          if (solved.to_set & vm_dependencies[group_name]).to_a == vm_dependencies[group_name]
            if_debug do
              puts "Provisioning #{group_name}"
            end

            provisioner = vm_groups[group_name]

            provision_block = lambda do
              # FIXME maybe a way to specify initial args?
              args = nil
              provisioner.each do |this_prov|
                vm_groups[group_name] = provisioner # force a write to the db
                unless args = this_prov.startup(args)
                  $stderr.puts "Could not provision #{group_name} with provisioner #{this_prov.class.name}"
                  raise "Could not provision #{group_name} with provisioner #{this_prov.class.name}"
                end
              end
              @queue << group_name
            end

            vm_working.add(group_name)

            if @serial
              # HACK: just give the working check something that will always work.
              #       Probably should just mock it.
              @working[group_name] = Thread.new { sleep }
              provision_block.call
            else
              @working[group_name] = Thread.new(&provision_block)
            end
          end
        end
      end

      if @serial
        waiter_iteration.call
      else
        @waiters_mutex.synchronize(&waiter_iteration)
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
        dependent_and_working = @working.keys & dependent_items

        if dependent_and_working.count > 0
          $stderr.puts "#{dependent_and_working.inspect} are depending on #{group_name}, which you are trying to deprovision."
          $stderr.puts "We can't resolve this problem for you, and future converges may fail during this run that would otherwise work."
          $stderr.puts "Consider using wait_for to better control the dependencies, or turning serial provisioning on."
        end

        deprovision_group(group_name)
      end

    end

    #
    # Performs the deprovision of a group by replaying its provision strategy
    # backwards and applying the #shutdown method instead of the #startup method.
    # Removes it from the various state tables if true is set as the second
    # argument, which is the default.
    #
    def deprovision_group(group_name, clean_state=true)
      provisioner = vm_groups[group_name]

      # if we can't find the provisioner, we probably got asked to clean up
      # something we never scheduled. Just ignore that.
      if provisioner and ((solved.to_set + vm_working.to_set).include?(group_name) or @force_deprovision)
        if_debug do
          puts "Attempting to deprovision group #{group_name}"
        end

        perform_deprovision = lambda do |this_prov|
          result = this_prov.shutdown
          unless result
            if_debug do
              puts "Could not deprovision group #{group_name}."
            end
          end
          result
        end

        provisioner.reverse.each do |this_prov|
          if @force_deprovision
            begin
              perform_deprovision.call(this_prov)
            rescue Exception => e
              if_debug do
                puts "Deprovision #{this_prov.class.name}/#{group_name} had errors:"
                puts "#{e.message}"
              end
            end
          else
            unless perform_deprovision.call(this_prov)
              raise "Could not deprovision #{group_name}/#{this_prov.inspect}"
            end
          end
        end
      end

      if clean_state
        solved.delete(group_name)
        @waiters_mutex.synchronize do
          @waiters.delete(group_name)
        end
        vm_working.delete(group_name)
        vm_dependencies.delete(group_name)
        vm_groups.delete(group_name)
      end
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
