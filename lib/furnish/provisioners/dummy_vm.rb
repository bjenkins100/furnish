require 'furnish/provisioners/dummy_include'
require 'furnish/provisioners/vm'

module Furnish
  module Provisioner
    class DummyVM < VM
      include Furnish::Provisioner::DummyInclude
    end
  end
end
