ActiveRecord::Base.class_eval do

    # The columns Hobo **adds** to a table that is somebody else's.
    #
    # `fields do ... end` is a model describing its whole table, and that is
    # what lets the migration generator propose dropping a column that is not in
    # it. When Hobo joins an application that already exists -- a model Rails
    # made, or the `User` of `bin/rails generate authentication` -- the right
    # thing to say is smaller: *these* are mine, the rest is not mine to touch.
    #
    #     add_fields do
    #       administrator :boolean, :default => false
    #     end
    def self.add_fields(&b)
      fields(&b)
      @hobo_owns_the_table = false
      self
    end

    def self.fields(include_in_migration = true, &b)
      # Any model that calls 'fields' gets a bunch of other
      # functionality included automatically, but make sure we only
      # include it once
      include HoboFields::Model unless HoboFields::Model.in?(included_modules)
      @include_in_migration ||= include_in_migration

      if b
        # A model that writes out its fields is describing its whole table.
        @hobo_owns_the_table = true
        dsl = HoboFields::FieldDeclarationDsl.new(self)
        if b.arity == 1
          yield dsl
        else
          dsl.instance_eval(&b)
        end
      end
    end


end
