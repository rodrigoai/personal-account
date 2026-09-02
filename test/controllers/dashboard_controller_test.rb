require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  include ActionDispatch::TestProcess::FixtureFile

  test "counts card purchases instead of their linked bank payment" do
    month = Date.current.beginning_of_month
    category = Category.create!(name: "Dashboard card shopping", kind: :outcome)
    payment = Transaction.create!(description: "CARD BILL PAYMENT", date: month, statement_month: month,
      amount: 30, direction: :outcome, category: category)
    Transaction.create!(description: "CARD SHOP", date: month, statement_month: month,
      transaction_kind: :credit_card, amount: 30, direction: :outcome, category: category)
    statement = StatementImport.new(kind: :credit_card, statement_month: month, account_name: "Dashboard card",
      statement_total: 30, status: :completed, bank_payment_transaction: payment)
    statement.file.attach(fixture_file_upload("santander_bank.csv", "text/csv"))
    statement.save!

    get dashboard_path, params: { month: month.strftime("%Y-%m") }

    assert_response :success
    assert_select ".kpi", text: /Outcomes/ do
      assert_select "strong", text: "R$ 30,00"
    end
    assert_select ".category-name", text: /Dashboard card shopping/ do
      assert_select "small", text: "1 entry"
    end
  end

  test "compares selected category totals over the twelve months ending in the dashboard month" do
    food = Category.create!(name: "Dashboard food", kind: :outcome, color: "#123456")
    groceries = Category.create!(name: "Dashboard groceries", kind: :outcome, parent: food)
    travel = Category.create!(name: "Dashboard travel", kind: :outcome)
    create_transaction("July groceries", Date.new(2026, 7, 1), 25, groceries)
    create_transaction("August groceries", Date.new(2026, 8, 1), 40, groceries)
    create_transaction("August food", Date.new(2026, 8, 1), 10, food)
    create_transaction("August travel", Date.new(2026, 8, 1), 80, travel)

    get dashboard_path, params: { month: "2026-08", category_ids: [food.id, travel.id] }

    assert_response :success
    assert_select ".category-filter summary", text: "Choose categories (2)"
    assert_select "#trend-category-#{food.id}[checked]"
    assert_select "#trend-category-#{travel.id}[checked]"
    assert_select ".month-filter-form input[name='category_ids[]'][value='#{food.id}']"
    assert_select ".month-filter-form input[name='category_ids[]'][value='#{travel.id}']"
    chart = css_select(".category-trend-chart[data-controller='category-trend-chart']").first
    assert chart
    assert_equal ["Sep 2025", "Oct 2025", "Nov 2025", "Dec 2025", "Jan 2026", "Feb 2026", "Mar 2026", "Apr 2026", "May 2026", "Jun 2026", "Jul 2026", "Aug 2026"],
      JSON.parse(chart["data-category-trend-chart-categories-value"])
    series = JSON.parse(chart["data-category-trend-chart-series-value"])
    assert_equal({ "name" => "Dashboard food", "data" => [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 25.0, 50.0] }, series.first)
    assert_equal({ "name" => "Dashboard travel", "data" => [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 80.0] }, series.second)
    assert_select "script[src='https://cdn.jsdelivr.net/npm/apexcharts@7.0.0/dist/apexcharts.min.js']"
    assert_select "svg.line-chart", count: 0
  end

  test "shows an invitation instead of an unfiltered category chart" do
    get dashboard_path, params: { month: "2026-08" }

    assert_response :success
    assert_select ".category-trend-empty strong", text: "Select categories to reveal their trend."
    assert_select ".category-trend-chart", count: 0
  end

  test "safely ignores invalid and missing category selections" do
    category = Category.create!(name: "Valid dashboard category", kind: :outcome)

    get dashboard_path, params: { month: "2026-08", category_ids: ["", category.id.to_s, category.id.to_s, "bad", "#{category.id}junk", "-1", "999999"] }

    assert_response :success
    assert_select ".category-filter summary", text: "Choose categories (1)"
    assert_select ".category-trend-chart", count: 1
  end

  private

  def create_transaction(description, month, amount, category)
    Transaction.create!(description: description, date: month, statement_month: month,
      amount: amount, direction: :outcome, category: category, categorization_status: :categorized)
  end
end
