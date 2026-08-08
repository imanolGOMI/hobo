require 'hobo_fields/types/enum_string'

module HoboFields

  # BasicObject rather than Object, so that a field can be named after any
  # method Object happens to define -- `hash`, `display`, `method`, `test`...
  # This is what the old hobo_support BlankSlate was for.
  class FieldDeclarationDsl < BasicObject

    # Anchored at the root: BasicObject has no Object in its ancestry, so
    # top-level constants are not reachable by the usual lookup.
    include ::HoboFields::Types::EnumString::DeclarationHelper

    def initialize(model)
      @model = model
    end

    attr_reader :model


    def timestamps
      field(:created_at, :datetime)
      field(:updated_at, :datetime)
    end


    def field(name, type, *args)
      @model.declare_field(name, type, *args)
    end


    def method_missing(name, *args)
      field(name, args.first, *args.drop(1))
    end

  end

end
