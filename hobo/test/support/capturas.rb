# Las mismas pantallas de las dos aplicaciones, para poder mirarlas una al lado
# de la otra desde el README de cada repositorio.
#
#   ruby capturas.rb 2   # http://localhost:3000 -> hobo2_mi_app/doc/capturas
#   ruby capturas.rb 3   # http://localhost:3001 -> hobo3_mi_app/doc/capturas
require "selenium-webdriver"
require "fileutils"

VERSION = ARGV[0] or abort("dime 2 o 3")

CONFIG = {
  "2" => { :port => 3000, :app => "hobo2_mi_app",
           :login_path => "/login",
           :fields => { "login" => "admin@example.com", "password" => "test1234" } },
  "3" => { :port => 3001, :app => "hobo3_mi_app",
           :login_path => "/session/new",
           :fields => { "email_address" => "admin@example.com", "password" => "test1234" } },
}.fetch(VERSION)

BASE = "http://localhost:#{CONFIG[:port]}"
OUT = File.expand_path("~/hobo_apps/#{CONFIG[:app]}/doc/capturas")
FileUtils.mkdir_p(OUT)

# Las mismas seis pantallas en las dos, con el mismo nombre de fichero: es lo
# que permite ponerlas en dos columnas y ver la diferencia de un vistazo.
PANTALLAS = [
  ["1-entrar",    CONFIG[:login_path]],
  ["2-listado",   "/books"],
  ["3-ficha",     "/books/1"],
  ["4-formulario", "/books/new"],
  ["5-prestamos", "/loans"],
  ["6-busqueda",  "/search?query=Delibes"],
]

options = Selenium::WebDriver::Firefox::Options.new
options.add_argument("-headless")
options.add_argument("--width=1280")
options.add_argument("--height=900")

driver = Selenium::WebDriver.for(:firefox, :options => options)
driver.manage.window.resize_to(1280, 900)

def shoot(driver, file)
  sleep 1.2
  driver.save_screenshot(file)
  puts "  #{File.basename(file)}"
end

begin
  # La primera pantalla se hace **antes** de entrar: es la que ve quien llega.
  driver.navigate.to("#{BASE}#{CONFIG[:login_path]}")
  shoot(driver, File.join(OUT, "1-entrar.png"))

  CONFIG[:fields].each do |name, value|
    field = driver.find_element(:name => name)
    field.clear
    field.send_keys(value)
  end
  driver.find_element(:css => "form [type=submit]").click
  sleep 2

  PANTALLAS.drop(1).each do |name, path|
    driver.navigate.to("#{BASE}#{path}")
    shoot(driver, File.join(OUT, "#{name}.png"))
  end
ensure
  driver.quit
end

puts "capturas en #{OUT}"
