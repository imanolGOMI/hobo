module HoboFields

  # What `fields do ... end` adds to a model.
  #
  # This was a `classy_module` -- Hobo's own DSL from 2008, which `class_eval`s
  # a block into whoever includes it. `ActiveSupport::Concern` says the same
  # thing with a name every Rails developer knows, and `included do` **is** that
  # `class_eval`: the body below is untouched, and `def self.x` still defines a
  # class method of the model, as it did before.
  #
  # (A finer split -- `class_methods do` for the class methods -- would read
  # better still, and it is a change to make on its own, with the suite as the
  # judge, not while removing a DSL.)
  module Model

    extend ActiveSupport::Concern

    included do

    # ignore the model in the migration until somebody sets
    # @include_in_migration via the fields declaration
    inheriting_cattr_reader :include_in_migration => false

    # Whether the model's `fields` declaration describes the **whole** table.
    #
    # It does when the model wrote a `fields do ... end` block: that is a model
    # saying what it has, and the migration generator can then propose dropping
    # a column that is not in it.
    #
    # It does not when Hobo only *added* to somebody else's table -- a lifecycle
    # putting its state and key columns on the `User` that Rails' authentication
    # generator made, or `include Hobo::Model` on a model of an application that
    # already existed. There, everything Hobo did not declare belongs to
    # somebody else, and the generator offered to **drop `email_address` and
    # `password_digest`**. Whoever pressed enter too fast lost their users.
    inheriting_cattr_reader :hobo_owns_the_table => false

    # attr_types holds the type class for any attribute reader (i.e. getter
    # method) that returns rich-types
    inheriting_cattr_reader :attr_types => HashWithIndifferentAccess.new
    inheriting_cattr_reader :attr_order => []

    # field_specs holds FieldSpec objects for every declared
    # field. Note that attribute readers are created (by ActiveRecord)
    # for all fields, so there is also an entry for the field in
    # attr_types. This is redundant but simplifies the implementation
    # and speeds things up a little.
    inheriting_cattr_reader :field_specs => HashWithIndifferentAccess.new

    # index_specs holds IndexSpec objects for all the declared indexes.
    inheriting_cattr_reader :index_specs => []
    inheriting_cattr_reader :ignore_indexes => []

    # eval avoids the ruby 1.9.2 "super from singleton method ..." error
    eval %(
      def self.inherited(klass)
        fields do |f|
          f.field(inheritance_column, :string)
        end
        index(inheritance_column)
        super
      end
    )

    def self.index(fields, options = {})
      # don't double-index fields
      index_specs << HoboFields::Model::IndexSpec.new(self, fields, options) unless index_specs.map(&:fields).include?(Array.wrap(fields).map(&:to_s))
    end

    # tell the migration generator to ignore the named index. Useful for existing indexes, or for indexes
    # that can't be automatically generated (for example: an prefix index in MySQL)
    def self.ignore_index(index_name)
      ignore_indexes << index_name.to_s
    end

    private

    # Declares that a virtual field that has a rich type (e.g. created
    # by attr_accessor :foo, :type => :email_address) should be subject
    # to validation (note that the rich types know how to validate themselves)
    def self.validate_virtual_field(*args)
      validates_each(*args) {|record, field, value| msg = value.validate and record.errors.add(field, msg) if value.respond_to?(:validate) }
    end


    # This adds a ":type => t" option to attr_accessor, where t is
    # either a class or a symbolic name of a rich type. If this option
    # is given, the setter will wrap values that are not of the right
    # type.
    # `attr_accessor :foo, :type => Markdown` -- a virtual attribute with a rich
    # type -- and acts_as_list declaring its position column. Both were
    # alias_method_chain; layer 4 prepends its own attr_accessor on top, and an
    # alias chain and a prepend end up calling each other for ever.
    module RichTypeAccessors

      def attr_accessor(*attrs)
        options = attrs.extract_options!
        type = options.delete(:type)
        attrs << options unless options.empty?
        # Since Ruby 3.0 a bare `public` inside a method body does nothing, and
        # attr_accessor returns the names it defined -- so make them public
        # explicitly.
        public(*super(*attrs))

        return unless type

        type = HoboFields.to_class(type)
        attrs.each do |attr|
          declare_attr_type attr, type, options
          type_wrapper = attr_type(attr)
          define_method "#{attr}=" do |val|
            if type_wrapper.not_in?(HoboFields::PLAIN_TYPES.values) && !val.is_a?(type) && HoboFields.can_wrap?(type, val)
              val = type.new(val.to_s)
            end
            instance_variable_set("@#{attr}", val)
          end
        end
      end

      # acts_as_list is not a dependency: the method only exists when it is there.
      def acts_as_list(options = {})
        declare_field(options.fetch(:column, "position"), :integer)
        default_scope { order("#{table_name}.position ASC") }
        super
      end

    end
    singleton_class.prepend(RichTypeAccessors)


    # Extend belongs_to so that it creates a FieldSpec for the foreign key.
    #
    # Since Rails 5 the signature is belongs_to(name, scope = nil, **options):
    # options are keyword arguments, not a positional hash. Passing the hash
    # positionally makes Rails take it for the scope and ask it for its arity.
    #
    # This is a prepended module rather than alias_method_chain because layer 4
    # prepends its own belongs_to on top. An alias chain and a prepend do not
    # compose: the alias captures the prepended method, and the two then call
    # each other until the stack runs out. It is exactly why Rails dropped
    # alias_method_chain in 5.1.
    module FieldDeclarationMacros

      def belongs_to(name, scope = nil, **options, &block)
        column_options = {}
        column_options[:null] = options.delete(:null) if options.has_key?(:null)
        column_options[:comment] = options.delete(:comment) if options.has_key?(:comment)

        index_options = {}
        index_options[:name] = options.delete(:index) if options.has_key?(:index)

        bt = super(name, scope, **options, &block)

        refl = reflections[name.to_s]
        fkey = refl.foreign_key
        declare_field(fkey.to_sym, :integer, column_options)
        if refl.options[:polymorphic]
          declare_polymorphic_type_field(name, column_options)
          index(["#{name}_type", fkey], index_options) if index_options[:name] != false
        else
          index(fkey, index_options) if index_options[:name] != false
        end
        bt
      end

    end
    singleton_class.prepend(FieldDeclarationMacros)


    # Declares the "foo_type" field that accompanies the "foo_id"
    # field for a polyorphic belongs_to
    def self.declare_polymorphic_type_field(name, column_options)
      type_col = "#{name}_type"
      declare_field(type_col, :string, column_options)
      # FIXME: Before hobo_fields was extracted, this used to now do:
      # never_show(type_col)
      # That needs doing somewhere
    end


    # Declare a rich-type for any attribute (i.e. getter method). This
    # does not effect the attribute in any way - it just records the
    # metadata.
    def self.declare_attr_type(name, type, options={})
      klass = HoboFields.to_class(type)
      attr_types[name] = HoboFields.to_class(type)
      klass.try(:declared, self, name, options)
    end


    # Declare named field with a type and an arbitrary set of
    # arguments. The arguments are forwarded to the #field_added
    # callback, allowing custom metadata to be added to field
    # declarations.
    def self.declare_field(name, type, *args)
      options = args.extract_options!
      try(:field_added, name, type, args, options)
      add_formatting_for_field(name, type, args)
      add_validations_for_field(name, type, args)
      add_index_for_field(name, args, options)
      unless HoboFields.plain_type?(type)
        declare_attr_type(name, type, options)
        # Register the rich type with ActiveRecord itself, so reading and
        # writing the attribute go through the Attributes API instead of the
        # private methods this used to override.
        attribute name, HoboFields::RichType.new(HoboFields.to_class(type))
      end
      field_specs[name] = HoboFields::Model::FieldSpec.new(self, name, type, options)
      attr_order << name unless name.in?(attr_order)
    end


    # Add field validations according to arguments in the
    # field declaration
    def self.add_validations_for_field(name, type, args)
      validates_presence_of   name if :required.in?(args)
      validates_uniqueness_of name, :allow_nil => !:required.in?(args) if :unique.in?(args)

      # Support for custom validations in Hobo Fields
      type_class = HoboFields.to_class(type)
      if type_class && type_class.public_method_defined?("validate")
        self.validate do |record|
          v = record.send(name)&.validate
          record.errors.add(name, v) if v.is_a?(String)
        end
      end

    end

    def self.add_formatting_for_field(name, type, args)
      type_class = HoboFields.to_class(type)
      if type_class && "format".in?(type_class.instance_methods)
        self.before_validation do |record|
          record.send("#{name}=", record.send(name)&.format)
        end
      end
    end

    def self.add_index_for_field(name, args, options)
      to_name = options.delete(:index)
      unless to_name
        # passing :unique => true doesn't do anything without an index
        Rails.logger.error('ERROR: passing :unique => true without :index => true does nothing. Use :unique instead.') if options[:unique]
        return
      end
      index_opts = {}
      index_opts[:unique] = :unique.in?(args) || options.delete(:unique)
      # support :index => true declaration
      index_opts[:name] = to_name unless to_name == true
      index(name, index_opts)
    end


    # Extended version of the acts_as_list declaration that
    # automatically delcares the 'position' field
    # Returns the type (a class) for a given field or association. If
    # the association is a collection (has_many or habtm) return the
    # AssociationReflection instead
    def self.attr_type(name)
      if attr_types.nil? && self != self.name.constantize
        raise RuntimeError, "attr_types called on a stale class object (#{self.name}). Avoid storing persistent references to classes"
      end

      attr_types[name] or

        if (refl = reflections[name.to_s])
          if refl.macro.in?([:has_one, :belongs_to]) && !refl.options[:polymorphic]
            refl.klass
          else
            refl
          end
        end or

        (col = column(name.to_s) and HoboFields::PLAIN_TYPES[col.type] || col.klass)
    end


    # Return the entry from #columns for the named column
    def self.column(name)
      return unless (@table_exists ||= table_exists?)
      name = name.to_s
      columns.find {|c| c.name == name }
    end

    end # included

  end

end
