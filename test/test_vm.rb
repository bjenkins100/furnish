require 'helper'

class TestVM < Furnish::TestCase
  def test_initialize
    vm = Furnish::VM.new
    kinds = {
      :groups       => Furnish::VMGroup,
      :dependencies => Furnish::VMGroup,
      :provisioned  => Palsy::Set,
      :working      => Palsy::Set,
      :waiters      => Palsy::Set,
    }

    kinds.each do |key, klass|
      assert_kind_of(klass, vm.send(key))
    end
  end
end
