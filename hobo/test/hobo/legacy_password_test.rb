require "test_helper"
require "digest/sha1"

# Entrar con la contraseña de siempre en una aplicación que viene de Hobo 2.
#
# Es el problema de toda migración real: la tabla trae `crypted_password` (SHA1
# con salt) y Rails 8 quiere `password_digest` (bcrypt). **De un hash no se saca
# la contraseña**, así que ningún script convierte una columna en la otra: la
# única persona que conoce la contraseña es quien la escribe al entrar.
#
# Escrito portando Amenti -- 33 columnas en `users` y ni una `password_digest`.
class LegacyPasswordTest < Minitest::Test

  def setup
    ActiveRecord::Base.connection.create_table(:legacy_people, :force => true) do |t|
      t.string :email_address
      t.string :password_digest
      t.string :crypted_password
      t.string :salt
    end

    Object.send(:remove_const, :LegacyPerson) if Object.const_defined?(:LegacyPerson)
    Object.const_set(:LegacyPerson, Class.new(ActiveRecord::Base) do
      self.table_name = "legacy_people"
      has_secure_password
      include Hobo::Model::LegacyPassword
    end)

    # Una cuenta de las de antes: su contraseña está en SHA1 y no tiene bcrypt.
    #
    # Se inserta sin validar a propósito, porque así es como está en una base de
    # datos de verdad: la fila la escribió Hobo 2 hace diez años, y
    # `has_secure_password` -- que hoy exige una contraseña al crear -- no
    # existía. Crearla con `create!` sería inventarse un caso que no se da.
    @salt = "sal-de-2012"
    LegacyPerson.new(
      :email_address => "vieja@example.com",
      :salt => @salt,
      :crypted_password => Digest::SHA1.hexdigest("--#{@salt}--secreta--")
    ).save!(:validate => false)
  end

  def teardown
    HoboTest.clean_up(:LegacyPerson)
    ActiveRecord::Base.connection.drop_table(:legacy_people, :if_exists => true)
  end

  def person = LegacyPerson.find_by(:email_address => "vieja@example.com")

  def test_a_password_from_hobo_2_still_lets_you_in
    found = LegacyPerson.authenticate_by(:email_address => "vieja@example.com", :password => "secreta")

    refute_nil found, "la contrasena de siempre tiene que valer"
    assert_equal "vieja@example.com", found.email_address
  end

  # Y al entrar queda convertida: la próxima vez ya es bcrypt.
  def test_and_the_password_is_moved_to_bcrypt
    assert_nil person.password_digest, "de partida no hay bcrypt"

    LegacyPerson.authenticate_by(:email_address => "vieja@example.com", :password => "secreta")

    assert person.password_digest.present?, "tiene que quedar guardada con bcrypt"
    assert person.authenticate("secreta"), "y tiene que ser la misma contrasena"
  end

  # El hash viejo se va. Dejarlo sería dejar SHA1 vivo para siempre, que es de
  # lo que se trataba de salir.
  def test_and_the_old_hash_is_gone
    LegacyPerson.authenticate_by(:email_address => "vieja@example.com", :password => "secreta")

    assert_nil person.crypted_password
    assert_nil person.salt
  end

  # Y a partir de ahí entra por el camino de Rails, sin pasar por aquí.
  def test_the_second_time_it_is_rails_who_answers
    LegacyPerson.authenticate_by(:email_address => "vieja@example.com", :password => "secreta")

    assert LegacyPerson.authenticate_by(:email_address => "vieja@example.com", :password => "secreta")
  end

  def test_a_wrong_password_is_still_wrong
    assert_nil LegacyPerson.authenticate_by(:email_address => "vieja@example.com", :password => "otra")
    assert person.crypted_password.present?, "y no se toca nada"
  end

  def test_somebody_who_is_not_there
    assert_nil LegacyPerson.authenticate_by(:email_address => "nadie@example.com", :password => "secreta")
  end

  # Una cuenta que ya está en bcrypt no pasa por aquí y sigue funcionando: el
  # concern se pone en el modelo y se queda, también cuando ya no queda nadie
  # por migrar.
  def test_an_account_already_on_bcrypt
    LegacyPerson.create!(:email_address => "nueva@example.com", :password => "test1234")

    assert LegacyPerson.authenticate_by(:email_address => "nueva@example.com", :password => "test1234")
    assert_nil LegacyPerson.authenticate_by(:email_address => "nueva@example.com", :password => "mal")
  end

end
