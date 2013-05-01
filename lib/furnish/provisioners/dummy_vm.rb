require 'furnish/provisioners/dummy_include'
require 'furnish/provisioners/vm'

module Furnish # :nodoc:
  module Provisioner # :nodoc:
    #
    # Primarily for testing, this is a provisioner that has a basic storage
    # model.
    #
    # In short, unless you're writing tests you should probably never use this
    # code.
    #
    class DummyVM < VM
      include Furnish::Provisioner::DummyInclude
    end
  end
end
