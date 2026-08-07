name = File.basename( __FILE__, '.gemspec' )
version = File.read(File.expand_path('../VERSION', __FILE__)).strip
require 'date'

Gem::Specification.new do |s|

  s.authors = ['Ignacio Huerta']
  s.email = 'ignacio@ihuerta.net'
  s.homepage = 'https://github.com/Hobo/hobo_bootstrap'
  s.summary = 'A Bootstrap based theme for Hobo'
  s.description = 'A Bootstrap based theme for Hobo'

  s.add_runtime_dependency('rails', ['>= 8.0'])
  s.add_runtime_dependency('hobo_rapid', ["= #{version}"])

  # Bootstrap 5 is shipped as a file in app/assets, not as a gem. The old
  # dependency was `bootstrap-sass ~> 2.1` -- Bootstrap 2.1, from 2012 -- and
  # the sass-based gems have been abandoned since Bootstrap moved to its own
  # build. One css file the engine serves is less machinery and easier to
  # replace: swap it for another framework and the contract does not change.

  s.add_development_dependency('rake', ['>= 13.0'])
  s.add_development_dependency('minitest', ['>= 5.0'])

  s.files = `git ls-files -x #{name}/* -z`.split("\0")

  s.name = name
  s.version = version
  s.date = Date.today.to_s

  s.required_ruby_version = ">= 3.2"
  s.required_rubygems_version = ">= 1.3.6"
  s.rdoc_options = ["--charset=UTF-8"]
  s.require_paths = ["lib"]

end
