require "json"
require "set"
$LOAD_PATH.unshift "/home/imanol/RubymineProjects/hobo_oficial_2027/hobo/hobo/lib"
require "hobo/bootstrap_migration"

medida = JSON.parse(File.read("/home/imanol/.claude/jobs/956f4927/tmp/medida.json"))
bs5 = Set.new(JSON.parse(File.read("/home/imanol/.claude/jobs/956f4927/tmp/bs5.json")))

# la raiz de cada aplicacion: el directorio que tiene app/views
apps = Dir["/mnt/e/APSOFT/UnoyCero/aplicaciones/**/app/views"].map { |d| File.dirname(File.dirname(d)) }.uniq
suyas = {}
apps.each { |root| suyas[root] = Hobo::BootstrapMigration.application_classes(root) }
puts "aplicaciones: #{apps.size}   clases propias (total distintas): #{suyas.values.reduce(Set.new, :|).size}"

restantes = Hash.new(0); conservadas = Hash.new(0)
Dir["/mnt/e/APSOFT/UnoyCero/aplicaciones/**/*.dryml"].each do |file|
  root = apps.find { |a| file.start_with?(a + "/") }
  keep = suyas[root] || Set.new
  text = File.read(file, :encoding => "UTF-8", :invalid => :replace, :undef => :replace)
  migrado, = Hobo::BootstrapMigration.apply(text, :from => 2, :keep => keep)
  migrado.scan(/class=["']([^"']*)["']/).flatten.each do |names|
    names.split.each do |n|
      next unless medida["gone"].key?(n) && !bs5.include?(n)
      keep.include?(n) ? conservadas[n] += 1 : restantes[n] += 1
    end
  end
end

puts "\nCONSERVADAS a proposito (las define el css de la aplicacion): #{conservadas.size} clases / #{conservadas.values.sum} apariciones"
conservadas.sort_by { |_, c| -c }.first(12).each { |n, c| puts format("  %5d  %s", c, n) }
puts "\nSIN CUBRIR: #{restantes.size} clases / #{restantes.values.sum} apariciones"
restantes.sort_by { |_, c| -c }.each { |n, c| puts format("  %5d  %s", c, n) }
