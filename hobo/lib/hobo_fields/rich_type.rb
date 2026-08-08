module HoboFields

  # Wraps a value in one of the rich types on the way out of the database, and
  # leaves everything else to the plain Rails type underneath.
  #
  # This is registered through ActiveRecord's Attributes API, which is the
  # supported way to do it since Rails 4.2. It replaces what used to be an
  # override of two private ActiveRecord methods, _read_attribute and
  # define_method_attribute=, both of which changed signature in Rails 8.
  class RichType < ActiveRecord::Type::Value

    attr_reader :wrapper_type, :subtype

    def initialize(wrapper_type, subtype = nil)
      @wrapper_type = wrapper_type
      @subtype = subtype || ActiveRecord::Type.lookup(wrapper_type::COLUMN_TYPE, :adapter => nil)
    end

    # The column type the migration generator should use.
    def type
      subtype.type
    end

    def cast(value)
      wrap(subtype.cast(value))
    end

    def deserialize(value)
      wrap(subtype.deserialize(value))
    end

    def serialize(value)
      subtype.serialize(value.nil? ? nil : value.to_s)
    end

    def changed_in_place?(raw_old_value, new_value)
      subtype.changed_in_place?(raw_old_value, new_value.nil? ? nil : new_value.to_s)
    end

    def ==(other)
      other.is_a?(RichType) && wrapper_type == other.wrapper_type && subtype == other.subtype
    end
    alias eql? ==

    def hash
      [self.class, wrapper_type, subtype].hash
    end

    private

    def wrap(value)
      return value if value.is_a?(wrapper_type)
      HoboFields.can_wrap?(wrapper_type, value) ? wrapper_type.new(value) : value
    end

  end

end
