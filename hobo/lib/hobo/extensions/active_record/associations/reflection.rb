module ActiveRecord
  module Reflection
    class AssociationReflection

      alias_method :association_name, :name

    end
  end
end

# A polymorphic belongs_to can name a class that does not exist yet -- Hobo
# conjures a shim so the association still answers. It was an alias chain.
module Hobo
  module PolymorphicShimClass
    def klass
      return super unless options[:polymorphic]
      begin
        super
      rescue NameError => e
        Object.class_eval "class #{e.missing_name} < ActiveRecord::Base; " \
                          "self.table_name = '#{active_record.name.tableize}'; " \
                          "def self.hobo_shim?; true; end; end"
        e.missing_name.constantize
      end
    end
  end
end

ActiveRecord::Reflection::AssociationReflection.prepend(Hobo::PolymorphicShimClass)
