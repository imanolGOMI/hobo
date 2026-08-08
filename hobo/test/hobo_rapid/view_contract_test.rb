require "test_helper"
require "rapid/param_contract"
require "hobo_rapid/tags/views"

# The layer-3 sweep, now pointed at the catalogue: every extension point these
# tags declare has to be reachable from outside. This is what stops a theme
# from silently losing a param, and it costs one line per tag.
class ViewContractTest < Minitest::Test
  include ParamContract::Assertions

  def test_every_param_of_view_is_overridable
    assert_every_param_overridable(:view, { :name => "un valor suelto", :this => "hola" })
  end

  def test_every_param_of_view_survives_a_collection
    assert_every_param_overridable(:collection_view,
                                   { :name => "una coleccion", :this => %w[uno dos] })
  end

  # And the point of the sweep, seen from the other side: overriding really
  # changes what comes out.
  def test_the_default_of_a_view_can_be_replaced
    outer = Rapid::Tag.new
    painted = Rapid::Context.capture do
      Rapid::Context.with(:this => "hola") do
        outer.call_tag(:view, {}, :default => Rapid.markup { text "otra cosa" })
      end
    end

    assert_includes painted, "otra cosa"
    refute_includes painted, "hola"
  end

end
