RUBY = File.join(RbConfig::CONFIG['bindir'], RbConfig::CONFIG['ruby_install_name']).sub(/.*\s.*/m, '"\&"')
GEMS_ROOT = File.expand_path('../')

# Gems whose suite has already been ported to minitest. Each layer of the plan
# adds its own gem here once its suite is green; see PLAN.md.
PORTED_GEMS = %w[hobo_support hobo_fields dryml]

# Gems whose port is under way: they load on Ruby 3.4 and have a minitest suite
# that runs, but the old suites (rubydoctest / irt) are still there and the
# layer is not finished. Listed apart so "green" is not read as "done".
PARTIAL_GEMS = %w[hobo hobo_rapid hobo_bootstrap]

# Gems still carrying the pre-2026 suites in full, not yet runnable.
PENDING_GEMS = %w[]

desc "Run the test suite of every ported gem"
task :test do |t|
  failed = (PORTED_GEMS + PARTIAL_GEMS).reject do |gem|
    puts "\n=== #{gem} ==="
    system("cd #{gem} && #{RUBY} -S rake test")
  end

  unless PARTIAL_GEMS.empty?
    puts "\nPort a medias, con suites viejas sin portar: #{PARTIAL_GEMS.join(', ')}"
  end

  unless PENDING_GEMS.empty?
    puts "\nSin portar todavia: #{PENDING_GEMS.join(', ')}"
  end

  unless failed.empty?
    puts "\nFallan: #{failed.join(', ')}"
    exit(1)
  end
end

desc "Run the integration tests (agility_bootstrap)"
task :test_integration do |t|
  system("cd integration_tests/agility_bootstrap && #{RUBY} -S rake test")
  exit($?.exitstatus)
end

desc "Build and push or install all the hobo-gems"
task :gems, :action, :force do |t, args|
  unless args.action.match(/^push|install|build$/)
    puts "Unknown '#{args.action}' action: it must be either 'push' or 'install' or 'build'."
    exit(1)
  end
  if ! args.force && ! `git status -s`.empty?
    puts <<-EOS.gsub(/^ {6}/, '')
      Rake task aborted: the working tree is dirty!
      If you know what you are doing you can use \`rake gems[#{args.action},force]\`"
    EOS
    exit(1)
  end


  %w[hobo_support hobo_fields dryml hobo hobo_rapid hobo_jquery hobo_jquery_ui hobo_clean hobo_clean_admin hobo_clean_sidemenu].each do |name|
    chdir(File.expand_path("../#{name}", __FILE__)) do
      orig_version = version = File.read('VERSION').strip
    begin
      # add the commit ID to the version, since it might not be the real gem version that will be published
      if args.action == 'install'
        commit_id = `git log -1 --format="%h" HEAD`.strip
        version = "#{orig_version}.#{commit_id}"
        File.open('VERSION', 'w') do |f|
          f.puts version
        end
      end

      gem_name = "#{name}-#{version}.gem"
      sh %(gem build #{name}.gemspec)
      sh %(gem #{args.action} #{gem_name} #{args.action == 'install' ? '--local' : ''}) unless args.action=='build'

    ensure
      remove_entry_secure gem_name, true unless args.action=='build'
      if args.action == 'install'
        File.open('VERSION', 'w') do |f|
          f.puts orig_version
        end
      end
    end

    end
  end

  if args.action == 'install'
    puts <<-EOS.gsub(/^ {6}/, '')

      *******************************************************************************
      *                                   NOTICE                                    *
      *******************************************************************************
      * The version id of locally installed hobo gems is comparable to a --pre      *
      * version: i.e. it is alphabetically ordered (not numerically ordered),       *
      * besides it includes the sah1 commit id which is not aphabetically ordered,  *
      * so be sure your application picks the version you really intend to use by   *
      * setting it explicitly in the Gemfile.                                       *
      *******************************************************************************

    EOS
  end

end
