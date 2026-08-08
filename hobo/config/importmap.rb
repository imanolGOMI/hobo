# The import map of the engine, merged into the application's.
#
# The names matter more than they look. The generated application says
# `eagerLoadControllersFrom("controllers", application)`, and that walks the
# import map for anything pinned under `controllers/` whose name ends in
# `_controller` -- so pinning them there is the whole of the wiring, and
# `controllers/rapid_input_many_controller` is what becomes
# `data-controller="rapid-input-many"`.
#
# Pinned one by one rather than with `pin_all_from`, which resolves its argument
# against the application's asset roots and quietly finds nothing when the files
# belong to an engine.
Dir[File.expand_path("../app/javascript/controllers/*_controller.js", __dir__)].sort.each do |file|
  name = File.basename(file, ".js")
  pin "controllers/#{name}", :to => "controllers/#{name}.js"
end
