name = File.basename( __FILE__, '.gemspec' )
version = File.read(File.expand_path('../VERSION', __FILE__)).strip
require 'date'

Gem::Specification.new do |s|

  s.authors = ['Tom Locke']
  s.email = 'tom@tomlocke.com'
  s.homepage = 'http://hobocentral.net'
  s.summary = 'The web app builder for Rails'
  s.description = 'The web app builder for Rails'

  # One gem (decision 11 of PLAN.md). hobo_support, hobo_fields, dryml,
  # hobo_rapid and the Bootstrap theme used to be five gems that depended on
  # each other in a line; they are one lib tree now, so there is nothing left to
  # declare. An application that installs `hobo` gets a working application:
  # the model layer, the tag runtime, the catalogue **and a theme**, which is
  # decision 13 -- a new application has to look right without installing
  # anything else.
  s.add_runtime_dependency('rails', ['>= 8.0'])
  s.add_runtime_dependency('hobo_will_paginate')
  # Ransack replaces the automatic scopes of piece 6; responders provides the
  # class-level `respond_to` and `respond_with` that Rails 5 moved out of core.
  s.add_runtime_dependency('ransack', ['>= 4.0'])
  s.add_runtime_dependency('responders', ['>= 3.0'])

  s.add_development_dependency('rake', ['>= 13.0'])
  s.add_development_dependency('minitest', ['>= 5.0'])
  s.add_development_dependency('sqlite3', ['>= 2.0'])
  s.add_development_dependency('capybara', ['>= 3.0'])
  s.add_development_dependency('selenium-webdriver', ['>= 4.0'])

  s.executables = ["hobo"]
  s.files = `git ls-files -x #{name}/* -z`.split("\0")

  s.name = name
  s.version = version
  s.date = Date.today.to_s

  s.required_ruby_version = ">= 3.2"
  s.required_rubygems_version = ">= 1.3.6"
  s.rdoc_options = ["--charset=UTF-8"]
  s.require_paths = ["lib"]

end
