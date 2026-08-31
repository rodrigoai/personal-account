require "test_helper"

class TransactionTest < ActiveSupport::TestCase
  test "search matches description notes account and category without requiring associations" do
    month = Date.current.beginning_of_month
    account = Account.create!(name: "Everyday bank", kind: :bank)
    category = Category.create!(name: "Groceries", kind: :outcome)
    purchase = Transaction.create!(date: month, statement_month: month, description: "Corner market", notes: "Weekend supplies", amount: 10, direction: :outcome, account: account, category: category)
    unassigned = Transaction.create!(date: month, statement_month: month, description: "Other market", amount: 20, direction: :outcome)

    assert_equal [purchase.id, unassigned.id].sort, Transaction.search("MARKET").pluck(:id).sort
    ["weekend", "everyday", "groceries"].each do |query|
      assert_equal [purchase.id], Transaction.search(query).pluck(:id)
    end
    assert_equal Transaction.count, Transaction.search(" ").count
    assert_empty Transaction.search("unknown")
  end

  test "search treats SQL wildcards and quotes as literal text" do
    month = Date.current.beginning_of_month
    literal = Transaction.create!(date: month, statement_month: month, description: "100% shop_special O'Brien", amount: 10, direction: :outcome)
    Transaction.create!(date: month, statement_month: month, description: "100 other shop special", amount: 10, direction: :outcome)

    ["%", "_", "O'Brien"].each do |query|
      assert_equal [literal.id], Transaction.search(query).pluck(:id)
    end
    assert_empty Transaction.search("' OR 1=1 --")
  end

  test "month scope includes rows in the requested month" do
    month = Date.new(2026, 8, 1)
    transaction = Transaction.create!(date: month, statement_month: month, description: "Test", amount: 10, direction: "outcome")
    assert_includes Transaction.for_month(month), transaction
  end

  test "categorized transactions require a compatible category" do
    income_category = Category.create!(name: "Salary", kind: :income)
    transaction = Transaction.new(date: Date.current, statement_month: Date.current.beginning_of_month, description: "Market", amount: 10, direction: :outcome, categorization_status: :categorized, category: income_category)

    assert_not transaction.valid?
    assert_includes transaction.errors[:category], "must match the transaction direction"
  end

  test "normalizes merchant keys and assigns source keys" do
    transaction = Transaction.create!(date: Date.current, statement_month: Date.current.beginning_of_month, description: "PIX 123456 Test Store", amount: 10, direction: :outcome)

    assert_equal "PIX TEST STORE", transaction.merchant_key
    assert_predicate transaction.source_key, :present?
  end
end
