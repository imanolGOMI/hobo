require "hobo_bootstrap/page"
require "hobo_bootstrap/engine" if defined?(Rails)

module HoboBootstrap
  VERSION = File.read(File.expand_path("../../VERSION", __FILE__)).strip rescue "2.2.6"
end
