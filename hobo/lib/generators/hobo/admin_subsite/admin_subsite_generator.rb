require "generators/hobo/subsite/subsite_generator"

module Hobo
  module Generators

    # `rails generate hobo:admin_subsite [name]`
    #
    # The subsite Hobo 2 asked about by name: a part of the application for
    # administrators. It is `hobo:subsite --administrators-only` with the name
    # already filled in -- one implementation, two doors.
    class AdminSubsiteGenerator < SubsiteGenerator

      source_root File.expand_path("../subsite/templates", __dir__)

      argument :subsite, :type => :string, :default => "admin",
               :desc => "Nombre del subsitio (por defecto: admin)"

      private

      def administrators_only? = true

    end

  end
end
