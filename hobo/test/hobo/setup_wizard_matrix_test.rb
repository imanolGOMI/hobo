require "test_helper"
require "rails/generators"
require "generators/hobo/setup_wizard/setup_wizard_generator"
require "tmpdir"
require "fileutils"

# **Todas** las respuestas posibles del asistente, no una muestra.
#
# El asistente tiene nueve respuestas que se multiplican entre si: 1.152
# aplicaciones distintas se pueden pedir por la linea de ordenes. Probar cuatro
# a mano deja 1.148 caminos que nadie ha recorrido nunca, y los fallos de este
# asistente han salido **todos** de combinaciones: la migracion que no tenia
# nada que hacer porque otra bandera ya lo habia hecho, el tema que no se
# instalaba porque la respuesta venia de una bandera y no de una pregunta.
#
# Que sea exhaustivo y no una muestra es posible porque **no genera
# aplicaciones**: pregunta y mira lo que decidio. Cada caso cuesta menos de un
# milisegundo, asi que la matriz entera cabe en la suite de siempre. Generar de
# verdad las 1.152 serian dos dias de reloj, y una prueba que nadie corre no
# protege nada.
#
# Lo que se comprueba en cada una son **invariantes**: cosas que tienen que ser
# ciertas pase lo que pase. No «con estas banderas sale esto» -- eso es copiar
# el codigo en el fichero de al lado -- sino «esto no puede pasar nunca».
class SetupWizardMatrixTest < Minitest::Test

  THEMES = %w[clean bootstrap none].freeze
  BEHAVIOURS = %w[stimulus jquery].freeze
  MIGRATIONS = [{}, { :skip_migration => true }, { :generate_migration => true }].freeze
  SI_O_NO = [true, false].freeze
  LOCALES = [%w[en], %w[en es]].freeze

  # Las gemas de mentira: la matriz corre dos veces, una en una maquina donde no
  # hay ningun plugin instalado y otra donde estan los tres. Es la diferencia
  # entre «el asistente no se cae» y «el asistente instala lo que dijiste».
  def with_plugins
    root = Dir.mktmpdir("hobo_matriz")
    { "hobo_bootstrap" => "theme", "hobo_jquery" => "behaviour", "hobo_jquery_ui" => "tags" }.each do |name, kind|
      FileUtils.mkdir_p(File.join(root, name))
      File.write(File.join(root, name, "#{name}.gemspec"), <<~RUBY)
        Gem::Specification.new do |s|
          s.name = #{name.inspect}
          s.version = "1.0.0"
          s.authors = ["Nadie"]
          s.summary = "Un plugin"
          s.metadata = { "hobo_plugin" => #{kind.inspect} }
        end
      RUBY
    end
    previous = ENV["HOBODEV"]
    ENV["HOBODEV"] = root
    Hobo::Plugins.reset
    yield
  ensure
    ENV["HOBODEV"] = previous
    Hobo::Plugins.reset
    FileUtils.remove_entry(root)
  end

  def every_combination
    THEMES.product(BEHAVIOURS, MIGRATIONS, SI_O_NO, SI_O_NO, SI_O_NO, SI_O_NO, SI_O_NO, LOCALES) do |combination|
      theme, behaviour, migration, invite, activation, admin, private_site, search, locales = combination

      options = {
        :wizard => false, :theme => theme, :behaviour => behaviour,
        :invite_only => invite, :activation_email => activation, :admin => admin,
        :private => private_site, :search => search, :locales => locales,
      }.merge(migration)

      generator = Hobo::Generators::SetupWizardGenerator.new([], options)
      generator.ask_the_questions
      yield generator, options
    end
  end

  def answer(generator, name) = generator.instance_variable_get(:"@#{name}")

  # --- lo que no puede pasar nunca ---------------------------------------------

  def test_every_combination_answers_without_raising
    casos = 0
    every_combination { |_generator, _options| casos += 1 }

    assert_equal 1152, casos, "la matriz ha cambiado de tamaño: revisa que sigue siendo exhaustiva"
  end

  # Una respuesta dada por bandera es la respuesta. Si el asistente la cambia
  # por su cuenta, lo que salga no es lo que se pidio -- y en un guion, nadie
  # esta mirando.
  def test_a_flag_is_never_overruled
    every_combination do |generator, options|
      assert_equal options[:theme], answer(generator, :theme)
      assert_equal options[:behaviour], answer(generator, :behaviour)
      assert_equal options[:private], answer(generator, :private)
      assert_equal options[:search], answer(generator, :search)
      assert_equal options[:admin], answer(generator, :admin)
      assert_equal options[:locales], answer(generator, :locales)
    end
  end

  # La unica excepcion, y es una de verdad: si se entra por invitacion no hay
  # alta que confirmar por correo. Las dos a la vez son una contradiccion, y el
  # asistente la deshace siempre en el mismo sentido.
  def test_an_invitation_never_asks_for_confirmation_by_email
    every_combination do |generator, _options|
      next unless answer(generator, :invite_only)

      assert_equal false, answer(generator, :activation_email),
                   "por invitacion y con correo de activacion a la vez"
    end
  end

  # El idioma por defecto tiene que estar entre los de la aplicacion: Rails
  # revienta en la primera peticion si no.
  def test_the_default_language_is_always_one_of_them
    every_combination do |generator, _options|
      assert_includes answer(generator, :locales), answer(generator, :locale)
    end
  end

  # Las tres respuestas de la base de datos y ninguna otra.
  def test_the_database_answer_is_always_one_of_the_three
    every_combination do |generator, _options|
      assert_includes %i[migrate generate skip], answer(generator, :migration)

      flags = generator.send(:migration_flags)
      assert_includes ["-n -m", "-n -g"], flags
      # Y el generador nunca vuelve a preguntar lo que ya se contesto aqui.
      assert_includes flags, "-n"
    end
  end

  # --- y lo mismo con los plugins puestos ----------------------------------------

  def test_what_comes_inside_is_never_installed
    with_plugins do
      every_combination do |generator, _options|
        nombres = generator.send(:chosen_plugins).map(&:name)

        refute_includes nombres, "clean"
        refute_includes nombres, "stimulus"
        refute_includes nombres, "none"
      end
    end
  end

  # Y lo que no viene dentro **si** se instala, siempre, en las 1.152.
  def test_what_was_chosen_is_always_installed
    with_plugins do
      every_combination do |generator, options|
        nombres = generator.send(:chosen_plugins).map(&:name)

        assert_includes nombres, "bootstrap" if options[:theme] == "bootstrap"
        assert_includes nombres, "jquery" if options[:behaviour] == "jquery"
        # Ni uno de mas: instalar algo que nadie pidio es tan malo como no
        # instalar lo que si.
        assert_equal nombres.uniq, nombres
        assert_operator nombres.length, :<=, 2
      end
    end
  end

  # La linea del Gemfile de cada plugin elegido, en las 1.152. Un plugin del
  # arbol de trabajo entra por `path:`; uno instalado, por su nombre.
  def test_every_chosen_plugin_can_say_its_gemfile_line
    with_plugins do
      every_combination do |generator, _options|
        generator.send(:chosen_plugins).each do |plugin|
          assert_match(/\Agem "hobo_\w+"/, plugin.gem_line)
          assert_includes plugin.gem_line, %(path: "), "un plugin del arbol de trabajo entra por path"
        end
      end
    end
  end

end
