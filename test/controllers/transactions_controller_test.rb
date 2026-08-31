require "test_helper"

class TransactionsControllerTest < ActionDispatch::IntegrationTest
  test "requires a category before marking a transaction categorized" do
    transaction = Transaction.create!(date: Date.current, statement_month: Date.current.beginning_of_month, description: "Market", amount: 10, direction: :outcome)

    patch transaction_path(transaction), params: { transaction: { category_id: "" } }

    assert_response :unprocessable_entity
    assert_predicate transaction.reload, :categorization_pending?
  end

  test "categorizes a transaction with a compatible category" do
    food = Category.create!(name: "Controller food", kind: :outcome)
    transaction = Transaction.create!(date: Date.current, statement_month: Date.current.beginning_of_month, description: "Market", amount: 10, direction: :outcome)

    patch transaction_path(transaction), params: { transaction: { category_id: food.id } }

    assert_redirected_to transactions_path
    assert_predicate transaction.reload, :categorization_categorized?
    assert_equal food, transaction.category
  end

  test "category changes reach matching transactions outside the current month and search filters" do
    old_category = Category.create!(name: "Old controller category", kind: :outcome)
    new_category = Category.create!(name: "New controller category", kind: :outcome)
    transaction = Transaction.create!(date: Date.new(2026, 8, 15), statement_month: Date.new(2026, 8, 1),
      description: "Recurring market", amount: 10, direction: :outcome,
      category: old_category, categorization_status: :categorized)
    match = Transaction.create!(date: Date.new(2026, 1, 15), statement_month: Date.new(2026, 1, 1),
      description: transaction.description, amount: 20, direction: :outcome, notes: "Original note")
    get transactions_path, params: { month: "2026-08", q: "No matching results", status: "review" }

    patch transaction_path(transaction), params: { transaction: { category_id: new_category.id, notes: "Edited note" } }

    assert_redirected_to transactions_path
    assert_equal new_category, transaction.reload.category
    assert_equal new_category, match.reload.category
    assert_predicate match, :categorization_categorized?
    assert_equal "Original note", match.notes
  end
end
