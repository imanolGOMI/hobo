require "rails/generators/active_record"

module Hobo
  module Generators

    # `rails generate hobo:model <name> <field:type>...`
    #
    # Rails' own model generator, plus the `fields do` block -- which is the
    # point: the model says what it has, and `hobo:migration` reads it back.
    # No migration is written here for the same reason.
    #
    # This used to be spread over three files and a `classy_module`
    # (`generators/hobo_support/model.rb`, `eval_template.rb`), which was the
    # 2008 way of sharing a Thor generator's body before `ActiveSupport::Concern`
    # existed. There is one user of all that, and it is this file, so it is this
    # file.
    class ModelGenerator < ActiveRecord::Generators::Base

      source_root File.expand_path("templates", __dir__)

      argument :attributes, :type => :array, :default => [],
               :banner => "field:type field:type"

      class_option :timestamps, :type => :boolean

      def generate_model
        invoke "active_record:model", [name], { :migration => false }.merge(options)
      end

      def inject_hobo_code_into_model_file
        gsub_file(model_path, /  # attr_accessible :title, :body\n/m, "")
        inject_into_class model_path, class_name do
          eval_template("model_injection.rb.erb")
        end
      end

      protected

      # `inject_into_class` takes the text to insert, so the template is
      # rendered here rather than written out.
      def eval_template(template_name)
        source = File.expand_path(find_in_source_paths(template_name))
        # Ruby 3 removed the `safe_level` argument, so the trim mode is a
        # keyword now: `ERB.new(src, nil, "-")` raised on every call.
        ERB.new(::File.binread(source), :trim_mode => "-").result(instance_eval("binding"))
      end

      def model_path = @model_path ||= File.join("app", "models", "#{file_path}.rb")

      def max_attribute_length = attributes.map { |attribute| attribute.name.length }.max

      # `bt` and `hm` are not fields: they are how this generator spells
      # `belongs_to` and `has_many` on the command line.
      def field_attributes = attributes.reject { |a| a.name.in?(%w[bt hm]) }

      def hms = attributes.select { |a| a.name == "hm" }.map(&:type)

      def bts = attributes.select { |a| a.name == "bt" }.map(&:type)

    end

  end
end
