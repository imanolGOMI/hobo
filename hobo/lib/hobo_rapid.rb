# The third gem with this line, and the third to be broken by it. It used to put
# the gem's own lib/ into ActiveSupport::Dependencies so the classic autoloader
# would resolve its constants; that autoloader is gone, and what survives of
# autoload_paths is the list Rails hands to **Zeitwerk** -- so the line
# registered lib/ as a Zeitwerk root and no application could boot.
#
# It only ever shows up inside a real Rails application. hobo_fields had it too,
# and layer 2 had declared that gem finished.

module HoboRapid

  VERSION = File.read(File.expand_path('../../VERSION', __FILE__)).strip
  @@root = Pathname.new File.expand_path('../..', __FILE__)
  def self.root; @@root; end

  EDIT_LINK_BASE = "https://github.com/Hobo/hobodoc/edit/master/hobo_rapid"

  # El contrato del comportamiento, que el catalogo escribe en el marcado.
  require 'hobo_rapid/behaviour'
  require 'hobo_rapid/theme'
  require 'hobo_rapid/previous_uri_filter'
  require 'hobo_rapid/tags/front_page'
  require 'hobo_rapid/tags/filters'
  require 'hobo_rapid/derivation'
  require 'hobo_rapid/helper'

end
