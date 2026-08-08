RUBY = File.join(RbConfig::CONFIG['bindir'], RbConfig::CONFIG['ruby_install_name']).sub(/.*\s.*/m, '"\&"')

# One gem (decision 11 of PLAN.md).
#
# There used to be three lists here -- PORTED_GEMS, PARTIAL_GEMS,
# PENDING_GEMS -- and they earned their keep: each layer moved a gem from one
# to the next, and `rake test` said out loud which ones were not being checked
# yet. That is over. `hobo_support`, `hobo_fields`, `dryml`, `hobo_rapid` and
# the Bootstrap theme are one lib tree under `hobo/`, with one gemspec, one
# Rakefile and one suite.
#
# The old themes and the jQuery plugins are still separate directories, and they
# are **not** ported: they are the Hobo 2 originals, kept to read. Nothing here
# runs them.
GEM = "hobo".freeze

desc "Run the test suite"
task :test do
  exit(1) unless system("cd #{GEM} && #{RUBY} -S rake test")
end

desc "Run the integration tests (agility_bootstrap)"
task :test_integration do
  system("cd integration_tests/agility_bootstrap && #{RUBY} -S rake test")
  exit($?.exitstatus)
end

desc "Build, install or push the gem"
task :gems, :action, :force do |t, args|
  unless args.action.to_s.match(/^push|install|build$/)
    puts "Unknown '#{args.action}' action: it must be either 'push' or 'install' or 'build'."
    exit(1)
  end
  if !args.force && !`git status -s`.empty?
    puts <<-EOS.gsub(/^ {6}/, '')
      Rake task aborted: the working tree is dirty!
      If you know what you are doing you can use `rake gems[#{args.action},force]`
    EOS
    exit(1)
  end

  chdir(File.expand_path("../#{GEM}", __FILE__)) do
    orig_version = version = File.read('VERSION').strip
    gem_name = nil
    begin
      # The commit id goes into a local install, because what is installed is
      # not necessarily what will be published.
      if args.action == 'install'
        version = "#{orig_version}.#{`git log -1 --format="%h" HEAD`.strip}"
        File.write('VERSION', "#{version}\n")
      end

      gem_name = "#{GEM}-#{version}.gem"
      sh %(gem build #{GEM}.gemspec)
      sh %(gem #{args.action} #{gem_name} #{args.action == 'install' ? '--local' : ''}) unless args.action == 'build'
    ensure
      remove_entry_secure gem_name, true if gem_name && args.action != 'build'
      File.write('VERSION', "#{orig_version}\n") if args.action == 'install'
    end
  end
end

task :default => :test
