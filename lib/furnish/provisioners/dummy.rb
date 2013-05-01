require 'furnish/provisioners/dummy_include'
require 'furnish/provisioners/api'

module Furnish
  module Provisioner
    #
    # Primarily for testing, this is a provisioner that has a basic storage
    # model.
    #
    # In short, unless you're writing tests you should probably never use this
    # code.
    #
    class Dummy < API
      include Furnish::Provisioners::DummyInclude
    end
  end
end
