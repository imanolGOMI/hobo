name = File.basename(__FILE__, ".gemspec")
version = File.read(File.expand_path("../VERSION", __FILE__)).strip

Gem::Specification.new do |s|

  s.authors = ["Hobo"]
  s.homepage = "https://hobo-project.org"
  s.summary = "Dates and times as '3 days ago', for Hobo"
  s.description = "A Hobo plugin: it replaces the date and time views of the " \
                  "catalogue with relative ones that keep themselves up to date."

  # A plugin depends on the gem whose tags it changes, and on nothing else.
  s.add_runtime_dependency("hobo")

  s.add_development_dependency("rake", [">= 13.0"])
  s.add_development_dependency("minitest", [">= 5.0"])

  s.files = `git ls-files -z`.split("\0")

  s.name = name
  s.version = version
  s.required_ruby_version = ">= 3.2"
  s.require_paths = ["lib"]

end
