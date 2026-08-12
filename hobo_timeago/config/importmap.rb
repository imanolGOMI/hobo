# Merged into the application's import map by the engine.
#
# Pinned under `controllers/` and named `*_controller`, because that is what the
# generated application's `eagerLoadControllersFrom("controllers", application)`
# walks: pinning it here is the whole of the wiring, and nothing in the
# application has to require anything.
pin "controllers/timeago_controller", :to => "controllers/timeago_controller.js"
