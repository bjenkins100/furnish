require 'helper'
require 'furnish/provisioners/dummy_vm'

DummyVM = Furnish::Provisioner::DummyVM

class TestProvisionerVM < Furnish::TestCase
  def test_definition
    assert_kind_of(Furnish::Provisioner::API, DummyVM.new)
    assert_kind_of(Furnish::Provisioner::VM, DummyVM.new)
    assert_respond_to(DummyVM.new, :vm)
    assert_equal([], DummyVM.new.list_vms)
    assert_raises(RuntimeError) { DummyVM.new.add_vm("foo", 1) }
    assert_raises(RuntimeError) { DummyVM.new.remove_vm("foo") }
  end

  def test_group
    dummy = DummyVM.new
    assert_nil(dummy.vm)
    group = Furnish::ProvisionerGroup.new([dummy], 'test1')

    assert_kind_of(Palsy::Map, group.first.vm)
    group
  end

  def test_api
    group = test_group
    group.first.add_vm("foo", "one" => "two", "three" => "four")
    assert_raises(ArgumentError) { group.first.add_vm("foo", 1) }
    assert_includes(group.first.list_vms, "foo")
    group.first.remove_vm("foo")
    refute_includes(group.first.list_vms, "foo")
  end
end
