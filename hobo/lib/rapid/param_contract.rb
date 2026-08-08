# The layer-3 contract: every extension point a tag declares stays reachable
# from outside.
#
# This is the non-negotiable of PLAN.md, layer 3, and spike C is why it exists.
# There the failure mode showed up on its own: a `param` whose override is
# looked up on the wrong object renders its default instead, the page still
# comes out, and nothing complains. Params get lost one at a time, in silence.
# That is what ruined the first attempt (HALLAZGOS.md).
#
# So the check is deliberately *not* a hand-written list of param names -- that
# list is the very thing that goes stale. It renders a tag, records every
# `param` the render actually reaches, and then demands that each one can be
# overridden from outside and that the override shows up in the output.
#
# A param nobody can reach is a param that does not exist.

# The gems above require this file on its own -- it is the whole point of it
# living in lib/ -- so it says what it needs instead of hoping somebody loaded
# the runtime first.
require "rapid"

module ParamContract

  # A mark no tag can produce by accident.
  SENTINEL = "<!--param-contract-sentinel-->".freeze

  # `path` is the address the outside world has to use to reach this param: the
  # names to nest through, or nil when nothing leads here. `kind` is which of
  # the three param sites it is -- :bare, :element or :call.
  Reached = Struct.new(:name, :rendered_by, :path, :kind) do
    def address = path || [:inalcanzable, rendered_by, name]
  end

  # Records every extension point the render reaches. The hook is on
  # `parameter_for`, which is the one thing the three kinds of param site have
  # in common -- a bare `param`, an element with a param, and a tag call exposed
  # with `as:`. Hooking `param` alone would miss two of the three.
  #
  # It is prepended to Rapid::Tag once and is inert unless a recording is
  # running, so it costs nothing outside the contract check.
  module Recorder
    private def parameter_for(name, kind)
      log = Thread.current[:param_contract_log]
      log << Reached.new(name, self.class, param_path && param_path + [name], kind) if log
      super
    end
  end

  Rapid::Tag.prepend(Recorder)

  class << self

    # Runs the block and returns the params the render actually reached, in the
    # order they were first seen. Params behind a condition only show up when
    # the scenario reaches them -- hence the several scenarios below.
    def params_reached
      previous = Thread.current[:param_contract_log]
      Thread.current[:param_contract_log] = []
      yield
      # By address, not by name: the same name at two depths is two different
      # extension points, and deduping by name loses the deeper one.
      Thread.current[:param_contract_log].uniq(&:address)
    ensure
      Thread.current[:param_contract_log] = previous
    end

    # The probe every param has to answer to: take the extension point away and
    # put the sentinel there. It works on all three kinds of site.
    def replacement = Rapid.parameter(:replace => true) { raw SENTINEL }

    # The everyday probe: fill the extension point in, leaving whatever wraps it
    # alone. It is not required of a tag call, because the tag being called is
    # free to ignore the content it is handed -- <search-filter> does.
    def filling = Rapid.parameter { raw SENTINEL }

  end

  module Assertions

    # `scenarios` is a hash, or a list of them, with :name, :attributes, :this
    # and :params -- enough variation to reach the params that sit behind a
    # condition.
    #
    # A param that lives inside a tag this one calls is reached by nesting --
    # `<table:><row:>...</row:></table:>` -- and the check builds that nesting
    # from the address it recorded, however deep it goes.
    #
    # `except` maps a param name to the reason it cannot be overridden from
    # here, and it is audited too: an exception that has become reachable, or
    # that names a param nobody declares any more, fails the test. An exception
    # list nobody audits is how params get lost in the first place.
    def assert_every_param_overridable(tag_name, scenarios, except: {})
      scenarios = [scenarios] if scenarios.is_a?(Hash)
      seen = {}

      scenarios.each do |scenario|
        ParamContract.params_reached { render_tag(tag_name, scenario) }.each do |reached|
          seen[reached.address] ||= [scenario, reached]
        end
      end

      refute_empty seen, "<#{tag_name}> no declaro ningun param en estos escenarios"

      seen.each_value { |scenario, reached| assert_param_overridable(tag_name, scenario, reached, except) }

      declared = seen.each_value.map { |_, reached| reached.name }
      assert_empty except.keys - declared,
                   "hay excepciones de <#{tag_name}> que ya no corresponden a ningun param declarado"
    end

    def render_tag(tag_name, scenario, extra_params = {})
      Rapid.render(tag_name,
                   scenario.fetch(:attributes, {}),
                   :this => scenario[:this],
                   **scenario.fetch(:params, {}),
                   **extra_params)
    end

    # Turns an address into the nested parameter a caller would have to write:
    # [:table, :row] becomes { :table => <parameter with { :row => value }> }.
    def nested_override(path, value)
      override = { path.last => value }
      path[0..-2].reverse_each { |name| override = { name => Rapid.parameter(:params => override) } }
      override
    end

    private

    def assert_param_overridable(tag_name, scenario, reached, except)
      excepted = except.key?(reached.name)
      where = "el param #{reached.name.inspect} de <#{tag_name}> " \
              "(alcanzado en #{scenario[:name].inspect}, lo resuelve #{reached.rendered_by})"

      if reached.path.nil?
        # Nothing leads here: the tag that declares it was called without
        # exposing the call as a param, so no amount of nesting reaches it.
        assert excepted,
               "#{where} no se puede sobreescribir desde fuera: nada lleva hasta el. " \
               "Expon la llamada con `as:`, o anotalo en `except:` con el motivo"
        return
      end

      address = reached.path.map(&:inspect).join(" > ")
      output = render_tag(tag_name, scenario, nested_override(reached.path, ParamContract.replacement))

      if excepted
        refute_includes output, ParamContract::SENTINEL,
                        "#{where} figura como inalcanzable (#{except[reached.name]}), " \
                        "pero el override en #{address} si llega: quita la excepcion"
        return
      end

      assert_includes output, ParamContract::SENTINEL,
                      "#{where} no se puede sobreescribir desde fuera: se declara, pero el " \
                      "override en #{address} no llega. Se perdio en silencio.\n" \
                      "Salida obtenida:\n#{output}"

      # A tag call is free to ignore the content it is handed, and a void
      # element has nowhere to put any: neither can be asked to be filled in.
      return if reached.kind == :call || reached.kind == :void_element

      filled = render_tag(tag_name, scenario, nested_override(reached.path, ParamContract.filling))
      assert_includes filled, ParamContract::SENTINEL,
                      "#{where} se puede reemplazar, pero no rellenar: el contenido pasado en " \
                      "#{address} no aparece.\nSalida obtenida:\n#{filled}"
    end

  end

end
