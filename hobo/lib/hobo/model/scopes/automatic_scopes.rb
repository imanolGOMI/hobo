# Los scopes que Hobo 2 fabricaba solo, por el nombre.
#
# `Expediente.created_between(enero, diciembre)`, `Factura.estado_is('emitida')`,
# `Cliente.nombre_contains('perez')`. Nadie los escribe: el nombre dice la
# columna y la pregunta, y el modelo sabe el resto. Un modelo de Hobo 2 los usa
# como si fueran suyos, y el que los lee no distingue -- ni tiene por que -- cual
# escribio el autor y cual salio de aqui.
#
# Se cayeron en el camino a Hobo 3 y `apply_scopes` se quedo, que es lo peor de
# los dos mundos: el mecanismo que **manda** nombres de scope seguia ahi y lo que
# los contestaba no. En amenti aparecio dentro de un `before_create`, tres capas
# por debajo del alta:
#
#   scope :current_year, lambda { created_between(...) }
#   NoMethodError: undefined method 'created_between'
#
# Y no es un caso raro: en las 115 aplicaciones del banco se cuentan `_is` por
# docenas -- `estado_is`, `company_is`, `cliente_is` --, `_between`, `_before` y
# `_after`.
#
# **Por `method_missing` y no por una lista**, igual que Hobo 2: las
# combinaciones son el producto de las columnas por las preguntas, y declararlas
# todas de antemano en un modelo de sesenta columnas es cargar cientos de metodos
# que nadie va a llamar. Lo que si se hace es definir el metodo la primera vez
# que se pregunta, para que la segunda ya no pase por aqui.
#
# Funciona igual sobre una relacion --`company.expedientes.current_year`-- sin
# tener que hacer nada: `ActiveRecord::Relation` delega en la clase lo que la
# clase dice saber contestar, y por eso `respond_to_missing?` es tan importante
# como `method_missing`.
module Hobo
  module Model
    module Scopes
      module AutomaticScopes

        # Un nombre puede casar con varios patrones, y **casar no es contestar**:
        # `company_is` parece una columna y `company` no lo es -- es un
        # `belongs_to` --, asi que ese patron no sabe construir nada y le toca al
        # siguiente. Hobo 2 lo resolvia metiendo la busqueda de la columna dentro
        # de la condicion del `when`; aqui se prueban en orden y gana el primero
        # que devuelve algo.
        def hobo_automatic_scope(name)
          name = name.to_s

          hobo_scope_patterns.each do |pattern, build|
            match = pattern.is_a?(Regexp) ? pattern.match(name) : (name == pattern ? [name] : nil)
            next unless match

            scope = instance_exec(match[1], &build)
            return scope if scope
          end

          nil
        end

        # En orden. La columna antes que la asociacion, porque `estado_is` es una
        # columna en casi todas las aplicaciones y la comprobacion es mas barata.
        def hobo_scope_patterns
          @hobo_scope_patterns ||= [
            # --- una columna y una pregunta ------------------------------------
            [/\A(.+)_is\z/,               ->(n) { hobo_scope_for_column(n) { |col, v| where(col.eq(v)) } }],
            [/\A(.+)_is_not\z/,           ->(n) { hobo_scope_for_column(n) { |col, v| where(col.not_eq(v)) } }],
            [/\A(.+)_contains\z/,         ->(n) { hobo_scope_for_column(n) { |col, v| where(col.matches("%#{v}%")) } }],
            [/\A(.+)_does_not_contain\z/, ->(n) { hobo_scope_for_column(n) { |col, v| where(col.does_not_match("%#{v}%")) } }],
            [/\A(.+)_starts\z/,           ->(n) { hobo_scope_for_column(n) { |col, v| where(col.matches("#{v}%")) } }],
            [/\A(.+)_does_not_start\z/,   ->(n) { hobo_scope_for_column(n) { |col, v| where(col.does_not_match("#{v}%")) } }],
            [/\A(.+)_ends\z/,             ->(n) { hobo_scope_for_column(n) { |col, v| where(col.matches("%#{v}")) } }],
            [/\A(.+)_does_not_end\z/,     ->(n) { hobo_scope_for_column(n) { |col, v| where(col.does_not_match("%#{v}")) } }],

            # --- la misma pregunta, sobre una asociacion -----------------------
            #
            # `company_is(empresa)`. Rails entiende la asociacion en un `where`,
            # asi que aqui no hay que saber como se llama su clave.
            [/\A(.+)_is\z/,     ->(n) { hobo_scope_for_belongs_to(n) { |assoc, v| where(assoc => v) } }],
            [/\A(.+)_is_not\z/, ->(n) { hobo_scope_for_belongs_to(n) { |assoc, v| where.not(assoc => v) } }],

            # --- una fecha -----------------------------------------------------
            #
            # `published_before` mira `published_at`, `published_date` o
            # `published_on`, que es como se llaman las columnas de fecha en una
            # aplicacion de Rails y lo que hacia Hobo 2.
            [/\A(.+)_before\z/,  ->(n) { hobo_scope_for_time(n) { |col, time| where(col.lt(time)) } }],
            [/\A(.+)_after\z/,   ->(n) { hobo_scope_for_time(n) { |col, time| where(col.gt(time)) } }],
            [/\A(.+)_between\z/, ->(n) { hobo_scope_for_time(n) { |col, from, to| where(col.between(from..to)) } }],

            # --- una asociacion ------------------------------------------------
            [/\A(?:with|any_of)_(.+)\z/, ->(n) { hobo_scope_for_association(n, :with) }],
            [/\Awithout_(.+)\z/,         ->(n) { hobo_scope_for_association(n, :without) }],

            # --- el propio registro, y el orden --------------------------------
            ["is",     ->(_) { ->(record) { where(primary_key => record) } }],
            ["is_not", ->(_) { ->(record) { where.not(primary_key => record) } }],
            ["by_most_recent", ->(_) { hobo_recency_scope { |relation| relation } }],
            ["recent", ->(_) { hobo_recency_scope { |relation, count = 6| relation.limit(count) } }],
            ["order_by", ->(_) { ->(field, direction = :asc) { hobo_order_by(field, direction) } }],

            # --- el nombre **es** la respuesta ---------------------------------
            [/\A(.+)\z/, ->(n) { hobo_flag_scope(n) }],
          ].freeze
        end

        # `company_is(empresa)`: la asociacion, no la columna.
        def hobo_scope_for_belongs_to(name, &query)
          reflection = reflect_on_association(name.to_sym)
          return nil unless reflection && %i[belongs_to has_one].include?(reflection.macro)
          ->(value) { instance_exec(reflection.name, value, &query) }
        end

        # `<x>` a secas: una columna booleana --`published`-- o un estado del
        # ciclo de vida --`active`--. Son los dos casos en que el nombre **es** la
        # respuesta y no lleva pregunta detras.
        def hobo_flag_scope(name)
          if (column = hobo_scope_column(name)) && hobo_column_type(name) == :boolean
            return -> { where(column.eq(true)) }
          end

          if name.start_with?("not_") && (column = hobo_scope_column(name.delete_prefix("not_"))) &&
             hobo_column_type(name.delete_prefix("not_")) == :boolean
            return -> { where(column.not_eq(true)) }
          end

          return nil unless respond_to?(:has_lifecycle?) && has_lifecycle?
          return nil unless self::Lifecycle.state_names.map(&:to_s).include?(name)

          field = self::Lifecycle.state_field
          -> { where(field => name) }
        end

        # --- de que columna habla el nombre ---------------------------------------

        def hobo_scope_column(name)
          return nil unless columns_hash.key?(name.to_s)
          arel_table[name.to_s]
        end

        def hobo_column_type(name) = columns_hash[name.to_s]&.type

        def hobo_scope_for_column(name, &query)
          column = hobo_scope_column(name)
          return nil unless column
          ->(value) { instance_exec(column, value, &query) }
        end

        # La columna de fecha que corresponde a `published`: `published_at`,
        # `published_date` o `published_on`. Y **tiene que ser de fecha**: sin
        # esto, `nombre_before` de un modelo con una columna `nombre_at` de texto
        # contestaria una consulta que no significa nada.
        TIME_SUFFIXES = %w[_at _date _on].freeze
        TIME_TYPES = %i[date datetime time timestamp].freeze

        def hobo_scope_for_time(name, &query)
          found = TIME_SUFFIXES.map { |suffix| "#{name}#{suffix}" }
                               .find { |candidate| TIME_TYPES.include?(hobo_column_type(candidate)) }
          return nil unless found

          column = arel_table[found]
          ->(*args) { instance_exec(column, *args, &query) }
        end

        # `with_comments`, `without_comments`, `any_of_comments`.
        #
        # Con Rails 8 esto es una linea y en Hobo 2 eran cuarenta de SQL a mano
        # con `EXISTS`: `joins` para «tiene alguno» y `where.missing` para «no
        # tiene ninguno», que existe desde Rails 6.1 y hace exactamente eso.
        #
        # El `hobo_` de delante no es adorno: sin el, este metodo se llamaba
        # `scope_for_association`, **que ya existe en ActiveRecord** -- lo llaman
        # las asociaciones al cargarse -- y quedaba pisado con otra firma. Cada
        # `company.user` moria con «wrong number of arguments», y el error salia
        # dentro de Rails, a tres saltos de aqui. Todo lo que este modulo mete en
        # una clase de modelo lleva el prefijo por eso.
        def hobo_scope_for_association(name, kind)
          reflection = reflect_on_association(name.to_sym) || reflect_on_association(name.pluralize.to_sym)
          return nil unless reflection

          association = reflection.name
          if kind == :without
            ->(*records) do
              next where.missing(association) if records.empty?
              where.not(id: unscoped.joins(association)
                                    .where(reflection.klass.table_name => { reflection.klass.primary_key => records })
                                    .select(primary_key))
            end
          else
            ->(*records) do
              relation = joins(association)
              relation = relation.where(reflection.klass.table_name => { reflection.klass.primary_key => records }) if records.any?
              relation.distinct
            end
          end
        end

        def hobo_recency_scope(&shape)
          return nil unless columns_hash.key?("created_at")
          ->(*args) { shape.call(order(:created_at => :desc), *args) }
        end

        def hobo_order_by(field, direction)
          direction = direction.to_s.downcase.start_with?("d") ? :desc : :asc
          return order(field.to_sym => direction) if columns_hash.key?(field.to_s)
          order(Arel.sql("#{connection.quote_column_name(field)} #{direction.to_s.upcase}"))
        end

        # --- la costura ------------------------------------------------------------

        def method_missing(name, *args, &block)
          scope = hobo_automatic_scope(name)
          return super if scope.nil?

          # Definido para la proxima: el patron se resuelve una vez por modelo y
          # por nombre, no una vez por llamada.
          singleton_class.define_method(name) { |*call| instance_exec(*call, &scope) }
          public_send(name, *args)
        end

        def respond_to_missing?(name, include_private = false)
          # Sin tabla no hay columnas que mirar, y preguntar por ellas mientras
          # se carga la clase --o con la base sin migrar-- levanta la conexion
          # entera. Un modelo sin tabla simplemente no tiene estos scopes.
          return super unless table_exists?
          !hobo_automatic_scope(name).nil? || super
        rescue StandardError
          super
        end

      end
    end
  end
end
