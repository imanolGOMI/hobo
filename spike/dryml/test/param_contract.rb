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

module ParamContract

  # A mark no tag can produce by accident.
  SENTINEL = "<!--param-contract-sentinel-->".freeze

  Reached = Struct.new(:name, :rendered_by)

  # Records every `param` call. Prepended to Rapid::Tag once, and inert unless a
  # recording is running, so it costs nothing outside the contract check.
  module Recorder
    def param(name, &default)
      log = Thread.current[:param_contract_log]
      log << Reached.new(name, self.class) if log
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
      Thread.current[:param_contract_log].uniq(&:name)
    ensure
      Thread.current[:param_contract_log] = previous
    end

    # An override that emits the sentinel and nothing else.
    def sentinel = Rapid.markup { raw SENTINEL }

  end

  module Assertions

    # `scenarios` is a hash, or a list of them, with :name, :attributes, :this
    # and :params -- enough variation to reach the params that sit behind a
    # condition.
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
          seen[reached.name] ||= [scenario, reached.rendered_by]
        end
      end

      refute_empty seen, "<#{tag_name}> no declaro ningun param en estos escenarios"

      seen.each do |name, (scenario, rendered_by)|
        output = render_tag(tag_name, scenario, name => ParamContract.sentinel)
        where = "el param #{name.inspect} de <#{tag_name}> " \
                "(alcanzado en #{scenario[:name].inspect}, ejecutado por #{rendered_by})"

        if except.key?(name)
          refute_includes output, ParamContract::SENTINEL,
                          "#{where} figura como inalcanzable (#{except[name]}), " \
                          "pero el override si llega: quita la excepcion"
        else
          assert_includes output, ParamContract::SENTINEL,
                          "#{where} se perdio en silencio: se declara, pero el override no llega.\n" \
                          "Salida obtenida:\n#{output}"
        end
      end

      assert_empty except.keys - seen.keys,
                   "hay excepciones de <#{tag_name}> que ya no corresponden a ningun param declarado"
    end

    def render_tag(tag_name, scenario, extra_params = {})
      Rapid.render(tag_name,
                   scenario.fetch(:attributes, {}),
                   :this => scenario[:this],
                   **scenario.fetch(:params, {}),
                   **extra_params)
    end

  end

end
