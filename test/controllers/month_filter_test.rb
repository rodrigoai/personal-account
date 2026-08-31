require "test_helper"

class MonthFilterTest < ActionDispatch::IntegrationTest
  setup do
    @july = Date.new(2026, 7, 1)
    @august = Date.new(2026, 8, 1)
    @july_category = Category.create!(name: "July purchases", kind: :outcome)
    @august_category = Category.create!(name: "August purchases", kind: :outcome)
    @july_transaction = create_transaction("July market", @july, @july_category)
    @august_transaction = create_transaction("August market", @august, @august_category)
  end

  test "month filters transactions by statement month and persists through pages and redirects" do
    @july_transaction.update!(date: @august)
    get transactions_path, params: { month: "2026-07" }
    assert_response :success
    assert_select ".transaction-description strong", text: "July market"
    assert_select ".transaction-description strong", text: "August market", count: 0

    get categories_path
    assert_select "#workspace-month[value='2026-07']"

    get dashboard_path
    assert_response :success
    assert_select ".category-name", text: /July purchases/
    assert_select ".category-name", text: /August purchases/, count: 0

    get reports_path
    assert_select ".report-row strong", text: "July purchases"
    assert_select ".report-row strong", text: "August purchases", count: 0

    patch transaction_path(@july_transaction), params: { transaction: { category_id: @july_category.id } }
    follow_redirect!
    assert_select "#workspace-month[value='2026-07']"
    assert_select ".transaction-description strong", text: "August market", count: 0
  end

  test "imports list uses the shared month without hiding directly opened statements" do
    july_import = create_import(@july, "July bank")
    august_import = create_import(@august, "August bank")

    get dashboard_path, params: { month: "2026-07" }
    get imports_path
    assert_select "a[href='#{import_path(july_import)}']"
    assert_select "a[href='#{import_path(august_import)}']", count: 0

    get import_path(august_import)
    assert_response :success
    assert_select "#workspace-month[value='2026-07']"
  end

  test "all months clears the filter across transactions reports overview and imports" do
    get transactions_path, params: { month: "2026-07" }
    get transactions_path, params: { month: "all" }
    assert_select ".transaction-description strong", text: "July market"
    assert_select ".transaction-description strong", text: "August market"

    [reports_path, dashboard_path].each do |path|
      get path
      assert_response :success
      assert_select ".month-filter-summary", text: "All months"
      assert_match "July purchases", response.body
      assert_match "August purchases", response.body
    end

    july_import = create_import(@july, "July bank")
    august_import = create_import(@august, "August bank")
    get imports_path
    assert_select "a[href='#{import_path(july_import)}']"
    assert_select "a[href='#{import_path(august_import)}']"

    get transactions_path, params: { month: "2026-08" }
    assert_select ".transaction-description strong", text: "July market", count: 0
    assert_select ".transaction-description strong", text: "August market"
  end

  test "invalid month parameters preserve the previous selection without raising" do
    get transactions_path, params: { month: "2026-07" }
    ["2026-13", "2026-02-01", "nonsense", "0000-01", ["2026-08"]].each do |month|
      get reports_path, params: { month: month }
      assert_response :success
      assert_select "#workspace-month[value='2026-07']"
    end
  end

  test "fresh sessions default to current month and an empty month means all months" do
    get transactions_path
    assert_select "#workspace-month[value='#{Date.current.strftime('%Y-%m')}']"

    get transactions_path, params: { month: "" }
    get reports_path
    assert_select ".month-filter-summary", text: "All months"
  end

  test "deleting another month does not change the active filter" do
    get imports_path, params: { month: "2026-07" }
    delete month_imports_path, params: { month: "2026-08" }
    follow_redirect!
    assert_select "#workspace-month[value='2026-07']"
    assert Transaction.exists?(@july_transaction.id)
    assert_not Transaction.exists?(@august_transaction.id)
  end

  test "search composes with month and review filters and persists after navigation" do
    matching = create_transaction("July market pending", @july, nil)
    create_transaction("July pharmacy pending", @july, nil)
    get transactions_path, params: { month: "2026-07", q: "  MARKET  ", status: "review" }
    assert_select ".transaction-description strong", text: matching.description
    assert_select ".transaction-row", count: 1
    assert_select "#transaction-search[value='MARKET']"
    assert_select ".month-filter-form input[name='status'][value='review']"
    assert_select ".transaction-search input[name='status'][value='review']"

    get categories_path
    get transactions_path
    assert_select ".transaction-row", count: 2
    assert_select "#transaction-search[value='MARKET']"
    assert_select "#workspace-month[value='2026-07']"

    get transactions_path, params: { q: "" }
    assert_select ".transaction-row", count: 3
    assert_select "#workspace-month[value='2026-07']"

    get transactions_path, params: { q: "no such transaction" }
    assert_select ".empty-state strong", text: "No matching transactions."
  end

  private

  def create_transaction(description, month, category)
    Transaction.create!(date: month, statement_month: month, description: description, amount: 10, direction: :outcome, category: category, categorization_status: category ? :categorized : :pending)
  end

  def create_import(month, name)
    StatementImport.new(kind: :bank, statement_month: month, account_name: name).tap do |statement_import|
      statement_import.file.attach(fixture_file_upload("santander_bank.csv", "text/csv"))
      statement_import.save!
    end
  end
end
