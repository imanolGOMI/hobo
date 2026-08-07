require "test_helper"

# The first thing layer 4 has to be able to say: a model that includes
# Hobo::Model loads, registers itself and answers the questions the rest of the
# gem asks of it.
class HoboModelTest < Minitest::Test

  def setup
    ActiveRecord::Base.connection.create_table(:stories, :force => true) do |t|
      t.string :title
      t.text :body
    end

    # Named before Hobo::Model goes in: the register is by name.
    Object.const_set(:Story, Class.new(ActiveRecord::Base))
    Story.class_eval do
      include Hobo::Model
      fields do
        title :string
        body  :text
      end
    end
  end

  def teardown
    HoboTest.clean_up(:Story)
  end

  def test_a_model_including_hobo_model_is_registered
    assert_includes Hobo::Model.all_models, Story
  end

  def test_the_name_attribute_is_guessed_from_the_fields
    assert_equal "title", Story.name_attribute.to_s
  end

  def test_the_fields_are_declared_as_hobo_fields
    assert_equal %w[title body], (Story.field_specs.keys.map(&:to_s) & %w[title body])
  end

end
