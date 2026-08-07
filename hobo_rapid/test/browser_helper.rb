# The browser bench for the Stimulus controllers.
#
# A Stimulus controller is behaviour in a browser, and the only honest way to
# check it is in one. These tests serve a small page with the controller on it,
# drive it with a real headless Firefox, and look at what happened to the DOM.
#
# The page is wired the way a Rails application wires it -- an import map that
# resolves `@hotwired/stimulus` -- so the controller under test is loaded
# exactly as it will be in an application, bare import and all.
#
# They skip, loudly, when the browser or Stimulus is not there:
#
#   cd hobo && rake test:app
require "minitest/autorun"

module BrowserBench

  CONTROLLERS = File.expand_path("../app/javascript/controllers", __dir__)
  APP_PATH = File.expand_path(ENV["HOBO_TESTAPP_PATH"] || "/tmp/hobo_testapp")
  STIMULUS = File.join(APP_PATH, "public", "vendor", "stimulus.js")

  class << self

    def why_not
      @why_not ||= begin
        if !File.exist?(STIMULUS)
          "no hay stimulus en #{STIMULUS}: montalo con `cd hobo && rake test:app`"
        elsif !system("which geckodriver > /dev/null 2>&1")
          "no hay geckodriver en el PATH"
        else
          begin
            require "capybara"
            require "selenium-webdriver"
            nil
          rescue LoadError => e
            "falta una gema del banco de navegador (#{e.message}): `cd hobo && rake test:app`"
          end
        end
      end
    end

    def ready? = why_not.nil?

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

    # Serves the page under test, the Stimulus runtime and the gem's own
    # controllers, straight from the working tree.
    def rack_app
      lambda do |env|
        case env["PATH_INFO"]
        when "/"
          [200, { "content-type" => "text/html" }, [@page.to_s]]
        when "/vendor/stimulus.js"
          [200, { "content-type" => "text/javascript" }, [File.read(STIMULUS)]]
        when %r{\A/controllers/([a-z_]+\.js)\z}
          file = File.join(CONTROLLERS, $1)
          File.exist?(file) ? [200, { "content-type" => "text/javascript" }, [File.read(file)]]
                            : [404, { "content-type" => "text/plain" }, ["no such controller"]]
        else
          [404, { "content-type" => "text/plain" }, ["not found"]]
        end
      end
    end

    def visit(controller, body)
      file = "#{controller.tr('-', '_')}_controller.js"
      raise ArgumentError, "no existe #{file}" unless File.exist?(File.join(CONTROLLERS, file))

      @page = <<~HTML
        <!DOCTYPE html>
        <html><head><meta charset="utf-8">
        <script type="importmap">
          { "imports": { "@hotwired/stimulus": "/vendor/stimulus.js" } }
        </script>
        </head>
        <body>
        #{body}
        <script type="module">
          import { Application } from "@hotwired/stimulus"
          import ControllerUnderTest from "/controllers/#{file}"
          const application = Application.start()
          application.register("#{controller}", ControllerUnderTest)
          application.element.dataset.stimulusReady = "yes"
        </script>
        </body></html>
      HTML

      session.visit("/")
      session.find("[data-stimulus-ready='yes']", :visible => :all, :wait => 10)
      session
    end

  end

end

Minitest.after_run { BrowserBench.session.driver.quit if BrowserBench.ready? && BrowserBench.instance_variable_get(:@session) }
