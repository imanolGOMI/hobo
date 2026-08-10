module Hobo

  # Los plugins que hay **en la maquina**, para que el asistente los ofrezca sin
  # tener una lista escrita a mano.
  #
  # Una gema dice que es un plugin de Hobo en su gemspec:
  #
  #   s.metadata["hobo_plugin"] = "theme"       # o "behaviour"
  #   s.summary = "El tema de Bootstrap para Hobo"
  #
  # Y eso es todo lo que hace falta. Instalas `hobo_lo_que_sea`, corres
  # `bin/rails generate hobo:setup_wizard` y la pregunta sale con la opcion
  # nueva dentro. Nadie tiene que tocar Hobo para que un plugin exista.
  #
  # Por que en el gemspec y no en el codigo: esto se pregunta **antes de
  # instalar**, cuando la gema todavia no esta en el Gemfile y por tanto no se
  # puede cargar. `Hobo.themes` y `Hobo.behaviours` -- los registros de
  # hobo.rb -- son la otra mitad, la de despues: quien esta puesto ahora mismo.
  # Uno es el catalogo de la tienda y el otro lo que hay en casa.
  #
  # El nombre del plugin es el de la gema sin `hobo_`, que es como se responde
  # la pregunta y como el plugin se apunta en el registro.
  module Plugins

    Plugin = Struct.new(:gem_name, :kind, :describe, :path, :metadata) do
      def name = gem_name.sub(/\Ahobo_/, "")

      # De donde saldra la linea del Gemfile. Un plugin del arbol de trabajo se
      # pone por `path:`, como hace `hobo new` con la gema principal.
      def gem_line = path ? %(gem "#{gem_name}", path: "#{path}") : %(gem "#{gem_name}")

      # Las hojas de estilo que el layout de la aplicacion tiene que enlazar,
      # si el plugin pide alguna:
      #
      #   s.metadata["hobo_plugin_stylesheets"] = "bootstrap hobo"
      #
      # Por defecto una que se llama como el plugin, que es lo normal.
      def stylesheets
        asked = metadata.to_h["hobo_plugin_stylesheets"].to_s.split
        asked.empty? ? [name] : asked
      end
    end

    class << self

      def all
        # El arbol de trabajo primero: si una gema esta instalada **y** en
        # desarrollo, la de desarrollo es la que se esta tocando. Es lo que hace
        # Bundler con `path:`.
        (working_tree + installed).uniq(&:gem_name)
      end

      def of(kind) = all.select { |plugin| plugin.kind == kind.to_s }

      def reset = @installed = @working_tree = nil

      private

      # Las gemas instaladas, leidas **del disco y no de Bundler**.
      #
      # Dentro de una aplicacion, `Gem::Specification` solo enseña lo que hay en
      # el Gemfile -- que es justo lo que aqui no sirve, porque la gracia es
      # ofrecer lo que todavia no esta puesto. Los ficheros de `specifications/`
      # son la lista de verdad de lo que hay instalado, y leerlos entera cuesta
      # una decima de segundo.
      def installed
        @installed ||= Gem.path.flat_map { |dir| Dir[File.join(dir, "specifications", "*.gemspec")] }
                          .filter_map { |file| plugin_from(file) }
                          .sort_by { |plugin| plugin.gem_name }
      end

      # Y los que se estan escribiendo, con HOBODEV puesto: la carpeta de las
      # gemas y la de al lado, que es donde viven los plugins mientras el
      # repositorio principal sigue teniendo dentro los de Hobo 2.
      #
      # Aquellos no aparecen por si solos: un gemspec de Hobo 2 no dice
      # `hobo_plugin`, asi que el `hobo_jquery` viejo y el nuevo se distinguen
      # sin nombrar a ninguno.
      def working_tree
        dev = ENV["HOBODEV"]
        return [] if dev.nil? || dev.empty?

        @working_tree ||= [dev, File.expand_path("..", dev)]
                          .flat_map { |root| Dir[File.join(root, "*", "*.gemspec")] }
                          .filter_map { |file| plugin_from(file, File.dirname(file)) }
                          .sort_by { |plugin| plugin.gem_name }
      end

      # Cargar un gemspec es evaluarlo, y el del arbol de trabajo llama a
      # `git ls-files`. Mirar antes si el fichero menciona la clave evita
      # arrancar un proceso por cada carpeta que hay al lado.
      def plugin_from(file, path = nil)
        return nil unless File.read(file).include?("hobo_plugin")

        spec = Gem::Specification.load(file)
        kind = spec&.metadata&.[]("hobo_plugin")
        return nil if kind.nil? || kind.empty?

        Plugin.new(spec.name, kind, spec.summary.to_s, path, spec.metadata)
      rescue StandardError
        # Un gemspec roto es problema de su gema, no del asistente.
        nil
      end

    end

  end

end
