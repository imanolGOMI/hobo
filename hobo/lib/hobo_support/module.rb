class Module

  private

  # In a module definition you can include a call to
  # included_in_class_callbacks(base) at the end of the
  # self.included(base) callback. Any modules that your module includes
  # will receive an included_in_class callback when your module is
  # included in a class. Useful if the sub-module wants to do something
  # like alias_method_chain on the class.
  def included_in_class_callbacks(base)
    if base.is_a?(Class)
      included_modules.each { |m| m.try(:included_in_class, base) }
    end
  end

  # Creates a class attribute reader that will delegate to the superclass
  # if not defined on self. Default values can be a Proc object that takes the class as a parameter.
  def inheriting_cattr_reader(*names)
    names_with_defaults = (names.pop if names.last.is_a?(Hash)) || {}

    (names + names_with_defaults.keys).each do |name|
      ivar_name = "@#{name}"
      block = names_with_defaults[name]
      self.send(self.class == Module ? :define_method : :define_singleton_method, name) do
        if instance_variable_defined? ivar_name
          instance_variable_get(ivar_name)
        else
          superclass.respond_to?(name) && superclass.send(name) ||
          block && begin
            result = block.is_a?(Proc) ? block.call(self) : block
            instance_variable_set(ivar_name, result) if result
          end
        end
      end
    end
  end

  def inheriting_cattr_accessor(*names)
    names_with_defaults = (names.pop if names.last.is_a?(Hash)) || {}

    names_with_defaults.keys.each do |name|
      attr_writer name
      inheriting_cattr_reader names_with_defaults.slice(name)
    end
    names.each do |name|
      attr_writer name
      inheriting_cattr_reader name
    end
  end


  # creates a #foo= and #foo? pair, with optional default values, e.g.
  # bool_attr_accessor :happy => true
  def bool_attr_accessor(*args)
    options = (args.pop if args.last.is_a?(Hash)) || {}

    (args + options.keys).each {|n| class_eval "def #{n}=(x); @#{n} = x; end" }

    args.each {|n| class_eval "def #{n}?; @#{n}; end" }

    options.keys.each do |n|
      class_eval %(def #{n}?
                     if !defined? @#{n}
                       @#{n} = #{options[n] ? 'true' : 'false'}
                     else
                       @#{n}
                     end
                   end)
      set_field_type(n => TrueClass) if respond_to?(:set_field_type)
    end
  end

end


# `classy_module` used to live here: Hobo's own way, from 2008, of extracting
# code from a class into a module while still writing it as a class body. It was
# `ActiveSupport::Concern` four years before Concern existed, and the plan
# (layer 1) said it would go when its last user did.
#
# Its last users were `HoboFields::Model`, the Thor mixins of the generators and
# a file of rake tasks from Hobo 2. The first is a Concern now, the second are
# ordinary generators, and the third is gone -- so this goes with them.
#
# Anything reaching for it should reach for `ActiveSupport::Concern`: `included
# do` is the same `class_eval`, and `class_methods do` says out loud what
# `def self.` inside a block only implied.


class Object

  def is_one_of?(*args)
    args.any? {|a| is_a?(a) }
  end

end
