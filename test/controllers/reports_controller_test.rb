require "test_helper"

class ReportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @month = Date.new(2026, 8, 1)
    @parent = Category.create!(name: "Report household", kind: :outcome)
    @child = Category.create!(name: "Report groceries", kind: :outcome, parent: @parent)
    @income = Category.create!(name: "Report salary", kind: :income)
    create_transaction(@parent, 20, :outcome)
    create_transaction(@child, 80, :outcome)
    create_transaction(@income, 250, :income)
    create_transaction(nil, 10, :outcome)
    create_transaction(@child, 500, :outcome, @month.prev_month)
  end

  test "renders parent and child totals with a single signed amount column" do
    get reports_path, params: { month: "2026-08" }
    assert_response :success
    assert_select ".report-table thead th", count: 3
    assert_select ".report-row", count: 4
    assert_select ".report-row[data-category-id='#{@parent.id}'][data-depth='0']" do
      assert_select ".report-count", text: "2"
      assert_select ".report-amount", text: "-R$ 100,00", count: 1
    end
    assert_select ".report-row[data-category-id='#{@child.id}'][data-depth='1'] .report-amount", text: "-R$ 80,00"
    assert_select ".report-row[data-category-id='#{@income.id}'] .report-amount", text: "+R$ 250,00"
    assert_select ".report-row[data-category-id=''] .report-amount", text: "-R$ 10,00"
    assert_summary "R$ 250,00", "R$ 110,00", "R$ 140,00"
  end

  test "all months summary counts transactions only once and supports a negative balance" do
    get reports_path, params: { month: "all" }
    assert_response :success
    assert_summary "R$ 250,00", "R$ 610,00", "-R$ 360,00"
  end

  test "empty periods still show a zero summary" do
    get reports_path, params: { month: "2026-06" }
    assert_response :success
    assert_select ".report-row", count: 0
    assert_select ".report-empty", text: "No transactions for this period."
    assert_summary "R$ 0,00", "R$ 0,00", "R$ 0,00"
  end

  test "parent category links preserve the report month and include descendants" do
    grandchild = Category.create!(name: "Report vegetables", kind: :outcome, parent: @child)
    create_transaction(grandchild, 15, :outcome)
    get transactions_path, params: { category_ids: [@income.id], q: "unrelated search", status: "review" }
    get reports_path, params: { month: "2026-08" }
    category_link = report_category_link(@parent, "2026-08")

    get category_link

    assert_response :success
    assert_select "#workspace-month[value='2026-08']"
    assert_select "#transaction-search[value='']"
    assert_select ".category-filter-active strong", text: @parent.name
    assert_select ".transaction-row", count: 3
    assert_select ".transaction-row .amount", text: "-R$ 20,00"
    assert_select ".transaction-row .amount", text: "-R$ 80,00"
    assert_select ".transaction-row .amount", text: "-R$ 15,00"
    assert_select ".filter.active", text: "All entries"
  end

  test "child category links filter only that subtree and retain a noncurrent report month" do
    get reports_path, params: { month: "2026-07" }
    category_link = report_category_link(@child, "2026-07")
    # A link carries its report period even if another tab changes the session month.
    get transactions_path, params: { month: "2026-08" }

    get category_link

    assert_response :success
    assert_select "#workspace-month[value='2026-07']"
    assert_select ".category-filter-active strong", text: @child.name
    assert_select ".transaction-row", count: 1
    assert_select ".transaction-row .amount", text: "-R$ 500,00"

    get transactions_path
    assert_select "#workspace-month[value='2026-07']"
    assert_select ".category-filter-active strong", text: @child.name
    assert_select ".transaction-row", count: 1
  end

  test "category links preserve all months" do
    get reports_path, params: { month: "all" }

    get report_category_link(@child, "all")

    assert_response :success
    assert_select ".month-filter-summary", text: "All months"
    assert_select ".category-filter-active strong", text: @child.name
    assert_select ".transaction-row", count: 2
    assert_select ".transaction-row .amount", text: "-R$ 80,00"
    assert_select ".transaction-row .amount", text: "-R$ 500,00"
  end

  private

  def report_category_link(category, month)
    path = transactions_path(category_ids: [category.id], month: month, q: "")
    assert_select ".report-row[data-category-id='#{category.id}'] a[href='#{path}']", text: category.name
    path
  end

  def assert_summary(income, outcome, balance)
    assert_select ".report-table > tfoot:last-child > tr:last-child.report-summary" do
      assert_select "td", count: 3
      assert_select "td:nth-child(1) strong", text: income
      assert_select "td:nth-child(2) strong", text: outcome
      assert_select "td:nth-child(3).report-balance strong", text: balance
    end
  end

  def create_transaction(category, amount, direction, month = @month)
    Transaction.create!(description: "Report entry", date: month, statement_month: month, category: category, amount: amount, direction: direction)
  end
end
