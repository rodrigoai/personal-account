require "test_helper"

class PendingTransactionClassifierTest < ActiveSupport::TestCase
  test "classifies existing pending transactions and assigns the fallback to unknowns" do
    food = Category.create!(name: "Existing food", kind: :outcome)
    recognized = Transaction.create!(date: Date.current, statement_month: Date.current.beginning_of_month, description: "Known market", amount: 10, direction: :outcome)
    unknown = Transaction.create!(date: Date.current, statement_month: Date.current.beginning_of_month, description: "Opaque code", amount: 20, direction: :outcome)
    classifier = Object.new
    classifier.define_singleton_method(:call) do
      { recognized.id => OpenaiTransactionClassifier::Result.new(category: food, confidence: BigDecimal("0.9")) }
    end

    summary = OpenaiTransactionClassifier.stub(:new, ->(*) { classifier }) do
      PendingTransactionClassifier.new(transactions: Transaction.where(id: [recognized.id, unknown.id])).call
    end

    assert_equal 1, summary.categorized
    assert_equal 1, summary.not_identified
    assert_equal food, recognized.reload.category
    assert_predicate recognized, :categorization_categorized?
    assert_equal Category.not_identified!, unknown.reload.category
    assert_predicate unknown, :categorization_pending?
  end
end
