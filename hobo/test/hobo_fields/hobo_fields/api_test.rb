require "test_helper"

# Ported from test/api.rdoctest. The original ran against a generated Rails
# test app; here the table is created directly, which tests the same API
# without a Rails app in the way. The attr_accessible lines are dropped:
# Rails removed them in 5.0.
class ApiTest < Minitest::Test

  def setup
    connection.drop_table(:adverts, :if_exists => true)
    connection.create_table :adverts do |t|
      t.string :title
      t.text   :body
      t.string :contact_address
    end
  end

  # A fresh named class per test, so declarations never leak between them.
  def advert_class(&block)
    define_model(:Advert) do
      self.table_name = "adverts"
      class_eval(&block) if block
    end
  end

  def teardown
    super
    connection.drop_table(:adverts, :if_exists => true)
  end

  def basic_advert
    advert_class do
      fields do
        title           :string
        body            :text
        contact_address :email_address
      end
    end
  end

  # --- Field types ----------------------------------------------------------

  def test_a_field_is_returned_as_the_type_it_was_declared
    advert = basic_advert.new(:body => "This is the body")

    assert_equal HoboFields::Types::Text, advert.body.class
  end

  def test_the_type_survives_a_round_trip_to_the_database
    klass = basic_advert
    advert = klass.create!(:body => "This is the body")

    assert_equal HoboFields::Types::Text, klass.find(advert.id).body.class
  end

  def test_a_wrapper_type_takes_the_underlying_value_in_its_constructor
    text = HoboFields::Types::Text.new("hello")

    assert_equal "hello", text
    assert_equal HoboFields::Types::Text, text.class
  end

  # --- Model extensions -----------------------------------------------------

  def test_attr_type_returns_the_declared_type
    klass = basic_advert

    assert_equal String, klass.attr_type(:title)
    assert_equal HoboFields::Types::Text, klass.attr_type(:body)
  end

  def test_column_is_a_shorthand_for_the_column_metadata
    column = basic_advert.column(:title)

    assert_equal "title", column.name
  end

  def test_attr_accessor_can_carry_a_type_for_a_virtual_field
    klass = basic_advert
    klass.class_eval { attr_accessor :my_attr, :type => :text }

    advert = klass.new
    advert.my_attr = "hello"

    assert_equal HoboFields::Types::Text, advert.my_attr.class
  end

  # --- Field validations ----------------------------------------------------

  def test_required_gives_a_presence_validation
    klass = advert_class { fields { title :string, :required } }
    advert = klass.new

    refute advert.valid?
    assert_equal ["Title can't be blank"], advert.errors.full_messages

    advert.title = "Jimbo"
    assert advert.save
  end

  def test_unique_gives_a_uniqueness_validation
    klass = advert_class { fields { title :string, :unique } }
    klass.create!(:title => "Jimbo")

    advert = klass.new(:title => "Jimbo")
    refute advert.valid?
    assert_equal ["Title has already been taken"], advert.errors.full_messages

    advert.title = "Sambo"
    assert advert.save
  end

  def test_a_rich_type_validate_can_be_called_directly
    advert = basic_advert.new(:contact_address => "not really an email address")

    assert_equal HoboFields::Types::EmailAddress, advert.contact_address.class
    assert_equal "is invalid", advert.contact_address.validate
  end

  def test_a_rich_type_validate_runs_during_validation
    advert = basic_advert.new(:contact_address => "not really an email address")

    refute advert.valid?
    assert_equal ["Contact address is invalid"], advert.errors.full_messages

    advert.contact_address = "me@me.com"
    assert advert.valid?
  end

  # --- Virtual fields -------------------------------------------------------

  def test_virtual_fields_are_not_validated_by_default
    klass = basic_advert
    klass.class_eval { attr_accessor :alternative_email, :type => :email_address }

    assert klass.new(:alternative_email => "woot!").valid?
  end

  def test_validate_virtual_field_opts_a_virtual_field_into_validation
    klass = basic_advert
    klass.class_eval do
      attr_accessor :alternative_email, :type => :email_address
      validate_virtual_field :alternative_email
    end

    refute klass.new(:alternative_email => "woot!").valid?
  end

end
