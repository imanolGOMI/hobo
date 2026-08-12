require "generators/hobo/front_controller/front_controller_generator"

module Hobo
  module Generators

    # The same generator under the other name. Hobo 2 called it
    # `front_controller` and that is what it writes; `front_page` is what it is
    # *for*, and it is the name this project used while building it.
    #
    # One implementation, two doors -- and no chance of them drifting apart.
    class FrontPageGenerator < FrontControllerGenerator

      source_root File.expand_path("../front_controller/templates", __dir__)

    end

  end
end
