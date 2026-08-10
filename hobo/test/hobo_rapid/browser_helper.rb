# El banco de navegador del **contrato**, no de una implementación.
#
# Hobo pinta un marcado que no nombra a nadie:
#
#   <ul data-rapid='{"input-many":{"prefix":"story[tasks]"}}'>
#     <li data-rapid-target="input-many:item">…</li>
#     <button data-rapid-action="input-many:add">+</button>
#
# y quien lo ejecuta es otro: los controladores de Stimulus que vienen dentro, o
# la gema `hobo_jquery`. Este banco sirve **el mismo html** a las dos y corre
# **las mismas pruebas** contra las dos. Si una hace algo distinto que la otra,
# sale aquí.
#
# Por qué existe así: antes las pruebas escribían el marcado de Stimulus a mano
# --`data-controller="rapid-input-many"`, `data-action="rapid-input-many#add"`--
# y eso es una forma que Hobo **ya no genera**: hoy la escribe el puente en
# tiempo de ejecución. Estaban en verde mirando algo que no sale de ningún sitio.
# Y en cuanto se miró el marcado de verdad apareció el primer fallo del
# contrato: al clonar una fila, Stimulus dejaba el atributo neutro diciendo
# «plantilla».
#
# Cada prueba se escribe una vez, en un módulo, y `BrowserBench.contract` la
# convierte en una clase por implementación:
#
#   InputManyStimulusTest, InputManyJqueryTest
#
# Se salta, en alto, cuando falta el navegador o la gema:
#
#   cd hobo && rake test:app
require "minitest/autorun"

module BrowserBench

  CONTROLLERS = File.expand_path("../../app/javascript/controllers", __dir__)
  APP_PATH = File.expand_path(ENV["HOBO_TESTAPP_PATH"] || "/tmp/hobo_testapp")
  STIMULUS = File.join(APP_PATH, "public", "vendor", "stimulus.js")

  # La gema del comportamiento en jQuery, que vive al lado del repositorio. No
  # es una dependencia de nada: si no está, esa mitad del banco se salta.
  JQUERY_GEM = File.expand_path(ENV["HOBO_JQUERY_PATH"] || "../../../../hobo_jquery", __dir__)

  IMPLEMENTATIONS = %i[stimulus jquery].freeze

  # Un módulo que muere se lleva la página entera y en silencio: lo que se ve es
  # «no encuentro tal elemento», que no dice nada. Esto guarda el error para que
  # el banco lo cuente. Sale de perder un rato con `import
  # "controllers/rapid_bridge"`, que en una aplicación lo resuelve el import map
  # y aquí no estaba puesto.
  ERROR_CATCHER = %(<script>window.addEventListener("error", (e) => ) +
                   %({ window.__rapid_error = String(e.message || e.error) })</script>)

  class << self

    # --- se puede correr? -------------------------------------------------------

    def missing_browser
      @missing_browser ||= if !system("which geckodriver > /dev/null 2>&1")
                             "no hay geckodriver en el PATH"
                           else
                             begin
                               require "capybara"
                               require "selenium-webdriver"
                               # Capybara sirve la página él mismo y necesita un
                               # servidor. Sin esto el banco no se saltaba: se
                               # caía, una vez por prueba, con un mensaje que no
                               # es un fallo de nada de lo que se prueba.
                               require "puma"
                               nil
                             rescue LoadError => e
                               "falta una gema del banco (#{e.message}): `cd hobo && rake test:app`"
                             end
                           end
    end

    def why_not(implementation)
      return missing_browser if missing_browser

      case implementation
      when :stimulus
        "no hay stimulus en #{STIMULUS}: montalo con `cd hobo && rake test:app`" unless File.exist?(STIMULUS)
      when :jquery
        "no esta hobo_jquery en #{JQUERY_GEM}" unless File.exist?(jquery_runtime) && File.exist?(jquery_behaviour)
      end
    end

    def ready?(implementation) = why_not(implementation).nil?

    def jquery_runtime = File.join(JQUERY_GEM, "vendor", "javascript", "jquery.js")
    def jquery_behaviour = File.join(JQUERY_GEM, "app", "javascript", "hobo_jquery.js")

    # --- la página ---------------------------------------------------------------

    # Los controladores que trae Hobo, con el nombre con el que se registran:
    # `rapid_input_many_controller.js` es `rapid-input-many`. Se registran
    # **todos**, no el que se está probando: el marcado neutro dice qué
    # comportamiento quiere, no qué controlador, así que quien decide es el
    # puente.
    def controllers
      Dir[File.join(CONTROLLERS, "*_controller.js")].sort.map do |file|
        name = File.basename(file, "_controller.js")
        [name.tr("_", "-"), File.basename(file)]
      end
    end

    def page_for(body, implementation)
      implementation == :jquery ? jquery_page(body) : stimulus_page(body)
    end

    def stimulus_page(body)
      imports = controllers.each_with_index.map { |(_, file), i| %(import C#{i} from "/controllers/#{file}") }
      registrations = controllers.each_with_index.map { |(name, _), i| %(application.register("#{name}", C#{i})) }

      <<~HTML
        <!DOCTYPE html>
        <html><head><meta charset="utf-8">
        <script type="importmap">
          { "imports": {
              "@hotwired/stimulus": "/vendor/stimulus.js",
              "controllers/rapid_bridge": "/controllers/rapid_bridge.js"
          } }
        </script>
        #{ERROR_CATCHER}
        </head>
        <body>
        #{body}
        <script type="module">
          import { Application } from "@hotwired/stimulus"
          #{imports.join("\n          ")}
          const application = Application.start()
          #{registrations.join("\n          ")}
          document.documentElement.dataset.rapidReady = "yes"
        </script>
        </body></html>
      HTML
    end

    def jquery_page(body)
      <<~HTML
        <!DOCTYPE html>
        <html><head><meta charset="utf-8">
        <script type="importmap">
          { "imports": { "jquery": "/vendor/jquery.js", "hobo_jquery": "/vendor/hobo_jquery.js" } }
        </script>
        #{ERROR_CATCHER}
        </head>
        <body>
        #{body}
        <script type="module">
          import "hobo_jquery"
          document.documentElement.dataset.rapidReady = "yes"
        </script>
        </body></html>
      HTML
    end

    # --- el servidor -------------------------------------------------------------

    def session
      @session ||= begin
        Capybara.register_driver(:hobo_firefox) do |app|
          options = Selenium::WebDriver::Firefox::Options.new
          options.add_argument("-headless")
          Capybara::Selenium::Driver.new(app, :browser => :firefox, :options => options)
        end
        Capybara.server = :puma, { :Silent => true }
        Capybara::Session.new(:hobo_firefox, rack_app)
      end
    end

    def js(file) = [200, { "content-type" => "text/javascript" }, [File.read(file)]]

    def rack_app
      lambda do |env|
        case env["PATH_INFO"]
        when "/"
          [200, { "content-type" => "text/html" }, [@page.to_s]]
        when "/vendor/stimulus.js"
          js(STIMULUS)
        when "/vendor/jquery.js"
          js(jquery_runtime)
        when "/vendor/hobo_jquery.js"
          js(jquery_behaviour)
        when %r{\A/controllers/([a-z_]+\.js)\z}
          file = File.join(CONTROLLERS, $1)
          File.exist?(file) ? js(file) : [404, { "content-type" => "text/plain" }, ["no such controller"]]
        else
          [404, { "content-type" => "text/plain" }, ["not found"]]
        end
      end
    end

    def visit(body, implementation)
      @page = page_for(body, implementation)
      session.visit("/")

      begin
        session.find("[data-rapid-ready='yes']", :visible => :all, :wait => 10)
      rescue Capybara::ElementNotFound
        died = session.evaluate_script("window.__rapid_error")
        raise "el javascript de #{implementation} no ha arrancado: #{died || 'sin error en la consola'}"
      end
      # Que el módulo haya cargado no quiere decir que haya arrancado: los dos
      # esperan a que el documento esté listo. Se espera a que algo del marcado
      # haya cambiado -- la plantilla, que los dos deshabilitan al arrancar.
      session
    end

    # --- una prueba, dos implementaciones ------------------------------------------

    # Convierte un módulo de pruebas en una clase por implementación. El nombre
    # sale del módulo, así que un fallo dice cuál de las dos ha sido:
    #
    #   InputManyJqueryTest#test_the_rows_are_numbered_from_zero
    def contract(behaviour)
      base = behaviour.name.sub(/Behaviour\z/, "")

      IMPLEMENTATIONS.each do |implementation|
        klass = Class.new(Minitest::Test) do
          include behaviour

          define_method(:implementation) { implementation }

          define_method(:setup) do
            skip BrowserBench.why_not(implementation) unless BrowserBench.ready?(implementation)
            @page = BrowserBench.visit(behaviour::MARKUP, implementation)
          end
        end

        Object.const_set("#{base}#{implementation.capitalize}Test", klass)
      end
    end

  end

end

Minitest.after_run { BrowserBench.session.driver.quit if BrowserBench.instance_variable_get(:@session) }
