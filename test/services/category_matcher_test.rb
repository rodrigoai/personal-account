require "test_helper"

class CategoryMatcherTest < ActiveSupport::TestCase
  test "reuses the latest exact description classification for the same account and direction" do
    account = Account.create!(name: "Santander", kind: :bank)
    food = Category.create!(name: "Matcher food", kind: :outcome)
    Transaction.create!(
      account: account,
      category: food,
      categorization_status: :categorized,
      date: Date.current,
      statement_month: Date.current.beginning_of_month,
      description: "COMPRA TEST MARKET",
      amount: 10,
      direction: :outcome
    )

    match = CategoryMatcher.new(description: "COMPRA TEST MARKET", direction: "outcome", account: account).call

    assert_equal food, match.category
    assert_equal BigDecimal("1.0"), match.confidence
  end

  test "does not match the same description in the opposite direction" do
    account = Account.create!(name: "Santander", kind: :bank)
    salary = Category.create!(name: "Salary", kind: :income)
    Transaction.create!(account: account, category: salary, categorization_status: :categorized, date: Date.current, statement_month: Date.current.beginning_of_month, description: "TRANSFER", amount: 10, direction: :income)

    match = CategoryMatcher.new(description: "TRANSFER", direction: "outcome", account: account).call

    assert_nil match.category
  end
end
