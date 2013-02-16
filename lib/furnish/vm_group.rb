module Furnish
  class VMGroup < Palsy::Generic
    include Enumerable

    def initialize(table_name, box_nil)
      super(table_name)
      @box_nil = box_nil
    end

    def [](key)
      rows = @db.execute("select value from #{@table_name} where name=? order by id", [Marshal.dump(key)])
      if rows.count == 0
        @box_nil ? [] : nil
      else
        rows.to_a.map { |x| Marshal.load(x.first) }
      end
    end

    def []=(key, value)
      delete(key)

      return value if value.empty?

      values = value.map { |x| Marshal.dump(x) }
      value_string = ("(?, ?)," * values.count).chop
      dumped_key = Marshal.dump(key)

      @db.execute("insert into #{@table_name} (name, value) values #{value_string}", values.map { |x| [dumped_key, x] }.flatten)
    end

    def keys
      @db.execute("select distinct name from #{@table_name}").map { |x| Marshal.load(x.first) }
    end

    def delete(key)
      @db.execute("delete from #{@table_name} where name=?", [Marshal.dump(key)])
    end

    def has_key?(key)
      @db.execute("select count(*) from #{@table_name} where name=?", [Marshal.dump(key)]).first.first.to_i > 0
    end

    def each
      keys.each do |key|
        yield key, self[key]
      end
    end

    def create_table
      @db.execute <<-EOF
        create table if not exists #{@table_name} (
          id integer not null primary key autoincrement,
          name varchar(255) not null,
          value text not null
        )
      EOF

      @db.execute <<-EOF
        create index if not exists #{@table_name}_name_index on #{@table_name} (name)
      EOF
    end
  end
end
