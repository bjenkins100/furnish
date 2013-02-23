require 'delegate'
require 'furnish/logger'

module Furnish
  class ProvisionerGroup < DelegateClass(Array)

    include Furnish::Logger::Mixins

    attr_reader :name
    attr_reader :dependencies

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
      @dependencies = dependencies

      super(provisioners)
    end

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

    def shutdown(force=false)
      reverse.each do |this_prov|
        begin
          unless perform_deprovision(this_prov) or force
            raise "Could not deprovision #{name}/#{this_prov.class.name}"
          end
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
      end
    end

    protected

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
