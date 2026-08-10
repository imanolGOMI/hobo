module HoboFields
  module Types
    class SerializedObject < Object

      COLUMN_TYPE = :text

      # `serialize :campo, Hash` dejo de existir en Rails 7.1: la clase pasa a
      # ser un argumento con nombre, y desde Rails 8 la forma vieja levanta
      # `wrong number of arguments (given 2, expected 1)`.
      #
      # Asi que **cualquier modelo con un campo `:serialized` no cargaba**, y no
      # lo decia nadie: no habia ninguna prueba que declarara ese tipo. Lo
      # encontro la vuelta completa de los diecisiete tipos por la migracion.
      #
      # Se aceptan las dos firmas porque esta gema tiene que poder cargarse en
      # un Rails anterior mientras alguien actualiza.
      def self.declared(model, name, options)
        type = options.delete(:class) || Object

        if model.method(:serialize).parameters.any? { |kind, _| kind == :key || kind == :keyrest }
          model.serialize(name, :type => type)
        else
          model.serialize(name, type)
        end
      end

      HoboFields.register_type(:serialized, self)

    end
  end
end
