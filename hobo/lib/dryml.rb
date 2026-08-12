# The gem's entry point is the layer-3 tag runtime. `Bundler.require` loads this
# file in every application that lists the gem, so it has to be the thing the
# gem actually is now.
require "rapid"

# The old DRYML compiler lives on in dryml/legacy.rb and is **not** loaded here.
# It needs erubis, dead since 2011, and it is kept for one purpose only: its
# parser is the front end of the updater that will migrate the templates of
# existing applications (PLAN.md, decision 6). Whoever writes that updater
# requires it on purpose:
#
#   require "dryml/legacy"
