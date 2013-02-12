require 'helper'

class TestVMGroup < Furnish::TestCase
  def test_initialize
    assert_raises(RuntimeError, "Must provide a table name!") { Furnish::VMGroup.new(nil, nil) }
    Furnish::VMGroup.new('test', nil)
  end

  def test_box_nil
    vmg         = Furnish::VMGroup.new('test', true)
    vmg_no_box  = Furnish::VMGroup.new('test_no_box', false)

    assert_nil(vmg_no_box["anything"], 'nil is returned when box_nil is false')
    assert_equal([], vmg["anything"], 'empty array is returned when box_nil is true')

    vmg["anything"] = [1]
    vmg_no_box["anything"] = [1]

    refute_nil(vmg_no_box["anything"], 'nil is returned when box_nil is false')
    refute_equal([], vmg["anything"], 'empty array is returned when box_nil is true')

    [vmg, vmg_no_box].each { |x| x.delete("anything") }

    assert_nil(vmg_no_box["anything"], 'nil is returned when box_nil is false')
    assert_equal([], vmg["anything"], 'empty array is returned when box_nil is true')
  end

  def test_subscripts
    vmg = Furnish::VMGroup.new('test', true)

    hash = [{ "one" => 1, "two" => 2 }]

    vmg["hash"] = hash
    assert_equal(hash, vmg["hash"], 'hash returns as expected')
    hash.first["three"] = 3
    refute_equal(hash, vmg["hash"], 'does not reflect modified state until set')
    vmg["hash"] = hash
    assert_equal(hash, vmg["hash"], 'reflects modified state once set')
    hash.push({ "distinct" => "test" })
    vmg["hash"] = hash
    assert_equal(hash, vmg["hash"], 'hash returns as expected (distinct test)')
  end

  def test_keys
    vmg = Furnish::VMGroup.new('test', true)

    keys = %w[one two three]
    keys.each { |key| vmg[key] = [1] }

    assert_equal(keys.sort, vmg.keys.sort, 'keys return as expected')

    keys.each { |key| vmg[key] = [1,2] }
    assert_equal(keys.sort, vmg.keys.sort, 'keys return as expected (distinct test)')
  end

  def test_delete_has_key
    vmg = Furnish::VMGroup.new('test', true)
    vmg["one"] = [1,2]
    assert(vmg.has_key?("one"), "key exists as it should")
    refute(vmg.has_key?("two"), "key does not exist as it should")

    vmg["two"] = [1,2]
    assert(vmg.has_key?("two"), "key exists as it should, update check")

    vmg.delete("two")
    refute(vmg.has_key?("two"), "key does not exist as it should, delete check")

    vmg["two"] = [1,2]
    assert(vmg.has_key?("two"), "key exists as it should, update post-delete check")
  end

  def test_each
    vmg = Furnish::VMGroup.new('test', true)

    keys = %w[one two three]
    keys.each { |key| vmg[key] = [1, key] }

    each_keys = []

    vmg.each do |key, value|
      assert_includes(keys, key, 'in list of keys')
      assert_equal([1, key], value, 'value is correct as set')
      each_keys.push(key)
    end

    assert_equal(keys.sort, each_keys.sort, 'iterated through the whole list of keys')
  end
end
