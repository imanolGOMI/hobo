module Hobo
  module Model

    # Las contraseñas de una aplicación que viene de Hobo 2, sin resetear
    # ninguna.
    #
    # Hobo 2 guardaba `Digest::SHA1.hexdigest("--#{salt}--#{password}--")` en
    # `crypted_password`. Rails 8 guarda un bcrypt en `password_digest`. **De un
    # hash no se saca la contraseña**: son de un solo sentido, así que ningún
    # script puede convertir una columna en la otra. Lo que sí se puede es
    # esperar a que la persona escriba su contraseña -- que es exactamente lo
    # que hace al entrar.
    #
    # Así que el primer login de cada cual hace la conversión:
    #
    #   1. se prueba `authenticate_by` de Rails: si ya tiene bcrypt, entra
    #   2. si no, se prueba el hash viejo con su salt
    #   3. si acierta, en ese instante tenemos la contraseña en claro y se
    #      guarda con bcrypt, y se borran `crypted_password` y `salt`
    #
    # Nadie se entera, nadie resetea nada, y la tabla se va migrando sola. Las
    # cuentas de quien no vuelva a entrar se quedan con el hash viejo, que es
    # justo lo que se quiere: no se pierde el acceso.
    #
    # SHA1 sin iteraciones es débil para contraseñas -- por eso Rails usa bcrypt
    # --, y esto es lo que saca a una aplicación de ahí sin pedirle nada a nadie.
    module LegacyPassword

      extend ActiveSupport::Concern

      # Cómo lo hacía Hobo 2, palabra por palabra: hobo/model/user_base.rb.
      def self.digest(password, salt)
        require "digest/sha1"
        Digest::SHA1.hexdigest("--#{salt}--#{password}--")
      end

      class_methods do

        def authenticate_by(attributes)
          found = super
          return found if found

          attributes = attributes.to_h.symbolize_keys
          password = attributes.delete(:password)
          return nil if password.blank? || attributes.empty?

          record = find_by(attributes)
          return nil unless record.respond_to?(:crypted_password) && record&.crypted_password.present?
          return nil unless LegacyPassword.digest(password, record.salt) == record.crypted_password

          record.adopt_password(password)
          record
        end

      end

      # Guarda la contraseña con el algoritmo de hoy y tira el de ayer.
      #
      # `update_columns` para el borrado: las validaciones de un modelo traído
      # de Hobo 2 pueden pedir cosas que este momento no tiene por qué cumplir
      # -- y lo que está pasando aquí no es un cambio del usuario, es una
      # conversión interna. Lo que no puede fallar es la contraseña nueva.
      def adopt_password(password)
        self.password = password
        save!(:validate => false)
        update_columns(:crypted_password => nil, :salt => nil) if has_attribute?(:crypted_password)
      end

    end

  end
end
