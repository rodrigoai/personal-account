require "test_helper"

class CategoryReportTest < ActiveSupport::TestCase
  test "groups income and outcomes by category" do
    food = Category.create!(name: "Report food", kind: :outcome)
    rows = [Transaction.new(description: "Lunch", date: Date.current, amount: 40, direction: "outcome", category: food), Transaction.new(description: "Pay", date: Date.current, amount: 100, direction: "income", category: food)]
    result = CategoryReport.new(rows).call
    assert_equal 40, result.first[:outcome]
    assert_equal 100, result.first[:income]
  end

  test "rolls child categories into their root" do
    housing = Category.create!(name: "Report housing", kind: :outcome)
    utilities = Category.create!(name: "Report utilities", kind: :outcome, parent: housing)
    row = Transaction.new(description: "Power", date: Date.current, amount: 80, direction: "outcome", category: utilities)

    result = CategoryReport.new([row]).call

    assert_equal housing, result.first[:category]
    assert_equal 80, result.first[:outcome]
    assert_equal [housing, utilities], result.map { |entry| entry[:category] }
    assert_equal [0, 1], result.map { |entry| entry[:depth] }
  end

  test "every ancestor includes descendants and directly assigned transactions exactly once" do
    root = Category.create!(name: "Report living", kind: :both)
    child = Category.create!(name: "Report bills", kind: :both, parent: root)
    grandchild = Category.create!(name: "Report electricity", kind: :outcome, parent: child)
    sibling = Category.create!(name: "Report rent", kind: :outcome, parent: root)
    rows = [
      report_transaction(root, 10, :outcome),
      report_transaction(child, 25, :outcome),
      report_transaction(child, 5, :income),
      report_transaction(grandchild, 40, :outcome),
      report_transaction(sibling, 100, :outcome)
    ]

    report = CategoryReport.new(rows)
    result = report.call
    assert_equal [root, sibling, child, grandchild], result.map { |row| row[:category] }
    assert_equal [0, 1, 1, 2], result.map { |row| row[:depth] }
    by_category = result.index_by { |row| row[:category] }
    assert_equal({ income: 5, outcome: 175, count: 5, balance: -170 }, by_category[root].slice(:income, :outcome, :count, :balance))
    assert_equal({ income: 5, outcome: 65, count: 3, balance: -60 }, by_category[child].slice(:income, :outcome, :count, :balance))
    assert_equal(-40, by_category[grandchild][:balance])
    assert_equal({ income: 5, outcome: 175, balance: -170 }, report.totals)
  end

  test "includes uncategorized amounts and preserves decimal precision" do
    report = CategoryReport.new([report_transaction(nil, "10.10", :income), report_transaction(nil, "3.03", :outcome)])
    row = report.call.sole

    assert_nil row[:category]
    assert_equal 0, row[:depth]
    assert_equal 2, row[:count]
    assert_equal BigDecimal("7.07"), row[:balance]
    assert_equal BigDecimal("7.07"), report.totals[:balance]
  end

  test "empty reports have zero totals" do
    report = CategoryReport.new([])
    assert_empty report.call
    assert_equal({ income: 0, outcome: 0, balance: 0 }, report.totals)
  end

  private

  def report_transaction(category, amount, direction)
    Transaction.new(description: "Report entry", date: Date.current, amount: amount, direction: direction, category: category)
  end
end
