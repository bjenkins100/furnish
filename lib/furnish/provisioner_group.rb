require 'delegate'
require 'furnish/logger'
require 'furnish/provisioner'

module Furnish
  #
  # A provisioner group is an array of provisioners. See Furnish::Provisioner
  # for what the Provisioner API looks like.
  #
  # A group has a set of provisioner objects, a name for the group, and a list
  # of names that count as dependencies. It has methods to operate on the group
  # as a unit, starting them up as a unit and shutting them down. It is
  # primarily operated on by Furnish::Scheduler.
  #
  # In general, you interact with this class via
  # Furnish::Scheduler#schedule_provision, but you can also construct groups
  # yourself and deal with them via
  # Furnish::Scheduler#schedule_provisioner_group.
  #
  # It delegates to Array and can be treated like one via the semantics of
  # Ruby's DelegateClass.
  #
  class ProvisionerGroup < DelegateClass(Array)

    include Furnish::Logger::Mixins

    # The name of the group.
    attr_reader :name
    # The list of names the group depends on.
    attr_reader :dependencies

    #
    # Create a new Provisioner group.
    #
    # * provisioners can be an array of provisioner objects or a single item
    #   (which will be boxed). This is what the array consists of that this
    #   object is.
    # * name is a string. always.
    # * dependencies can either be passed as an Array or Set, and will be
    #   converted to a Set if they are not a Set.
    #
    def initialize(provisioners, name, dependencies=[])
      #
      # FIXME maybe move the naming construct to here instead of populating it
      #       out to the provisioners
      #

      provisioners = [provisioners] unless provisioners.kind_of?(Array)
      provisioners.each do |p|
        p.name = name
      end

      @name         = name
      @dependencies = dependencies.kind_of?(Set) ? dependencies : Set[*dependencies]

      super(provisioners)
    end

    #
    # Provision this group.
    #
    # Initial arguments go to the first provisioner's startup method, and then
    # the return values, if truthy, get passed to the next provisioner's
    # startup method. Any falsey value causes a RuntimeError to be raised and
    # provisioning halts, effectively creating a chain of responsibility
    # pattern.
    #
    def startup(*args)
      each do |this_prov|
        unless args = this_prov.startup(args)
          if_debug do
            puts "Could not provision #{this_prov.name} with provisioner #{this_prov.class.name}"
          end

          raise "Could not provision #{this_prov.name} with provisioner #{this_prov.class.name}"
        end
      end

      return true
    end

    #
    # Deprovision this group.
    #
    # Provisioners are run in reverse order against the shutdown method. No
    # arguments are seeded as in Furnish::ProvisionerGroup#startup. Raise
    # semantics are the same as with Furnish::ProvisionerGroup#startup.
    #
    # If a true argument is passed to this method, the raise semantics will be
    # ignored (but still logged), allowing all the provisioners to run their
    # shutdown routines. See Furnish::Scheduler#force_deprovision for
    # information on how to use this externally.
    #
    def shutdown(force=false)
      reverse.each do |this_prov|
        success = false

        begin
          success = perform_deprovision(this_prov) || force
        rescue Exception => e
          if force
            if_debug do
              puts "Deprovision #{this_prov.class.name}/#{this_prov.name} had errors:"
              puts "#{e.message}"
            end
          else
            raise e
          end
        end

        unless success or force
          raise "Could not deprovision #{this_prov.name}/#{this_prov.class.name}"
        end
      end
    end

    protected

    #
    # Just a way to simplify the deprovisioning logic with some generic logging.
    #
    def perform_deprovision(this_prov)
      result = this_prov.shutdown
      unless result
        if_debug do
          puts "Could not deprovision group #{this_prov.name}."
        end
      end
      return result
    end
  end
end
