require "test_helper"

class OpenaiTransactionClassifierTest < ActiveSupport::TestCase
  test "accepts compatible confident classifications from structured output" do
    food = Category.create!(name: "Classifier food", kind: :outcome)
    classifier = build_classifier(food, category_id: food.id, confidence: 0.92)

    result = classifier.call.fetch(4)

    assert_equal food, result.category
    assert_equal BigDecimal("0.92"), result.confidence
  end

  test "rejects low confidence and direction-incompatible classifications" do
    salary = Category.create!(name: "Classifier salary", kind: :income)
    low_confidence = build_classifier(salary, category_id: salary.id, confidence: 0.2, direction: "income").call.fetch(4)
    incompatible = build_classifier(salary, category_id: salary.id, confidence: 0.95, direction: "outcome").call.fetch(4)

    assert_nil low_confidence.category
    assert_nil incompatible.category
  end

  test "requires an API key when there are transactions to classify" do
    classifier = OpenaiTransactionClassifier.new(rows: [row], categories: [Category.create!(name: "Any", kind: :both)], api_key: nil)

    error = assert_raises(OpenaiTransactionClassifier::ConfigurationError) { classifier.call }

    assert_match "OPENAI_API_KEY", error.message
  end

  private

  def build_classifier(category, category_id:, confidence:, direction: "outcome")
    response = {
      output: [{
        type: "message",
        content: [{
          type: "output_text",
          text: JSON.generate(classifications: [{ transaction_index: 4, category_id: category_id, confidence: confidence }])
        }]
      }]
    }
    klass = Class.new(OpenaiTransactionClassifier) do
      define_method(:perform_request) { |_payload| JSON.generate(response) }
    end
    klass.new(rows: [row(direction:)], categories: [category], api_key: "test-key")
  end

  def row(direction: "outcome")
    { transaction_index: 4, date: Date.new(2026, 8, 1), description: "TEST MERCHANT", amount: BigDecimal("25.50"), direction: direction }
  end
end
