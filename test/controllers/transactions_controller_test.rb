require "test_helper"

class TransactionsControllerTest < ActionDispatch::IntegrationTest
  test "orders transactions by date, name, or value in either direction" do
    month = Date.current.beginning_of_month
    alpha = create_sortable_transaction("Sort marker Alpha", month + 2.days, 30)
    beta = create_sortable_transaction("Sort marker beta", month + 1.day, 10)
    gamma = create_sortable_transaction("Sort marker Gamma", month + 3.days, 20)

    {
      ["date", "asc"] => [beta, alpha, gamma],
      ["date", "desc"] => [gamma, alpha, beta],
      ["name", "asc"] => [alpha, beta, gamma],
      ["name", "desc"] => [gamma, beta, alpha],
      ["value", "asc"] => [beta, gamma, alpha],
      ["value", "desc"] => [alpha, gamma, beta]
    }.each do |(sort, direction), expected|
      get transactions_path, params: { q: "sort marker", sort: sort, direction: direction }

      assert_response :success
      assert_equal expected.map(&:description), transaction_names
      assert_select "select[name='sort'] option[selected][value='#{sort}']"
      assert_select "select[name='direction'] option[selected][value='#{direction}']"
      assert_select ".month-filter-form input[name='sort'][value='#{sort}']"
      assert_select ".month-filter-form input[name='direction'][value='#{direction}']"
    end
  end

  test "falls back to newest date first for invalid ordering parameters" do
    month = Date.current.beginning_of_month
    older = create_sortable_transaction("Invalid sort marker older", month + 1.day, 10)
    newer = create_sortable_transaction("Invalid sort marker newer", month + 2.days, 20)

    get transactions_path, params: { q: "invalid sort marker", sort: "amount desc; drop table transactions", direction: "sideways" }

    assert_response :success
    assert_equal [newer.description, older.description], transaction_names
    assert_select "select[name='sort'] option[selected][value='date']"
    assert_select "select[name='direction'] option[selected][value='desc']"
  end

  test "shows the weekday and a location-aware Google search on the list and review page" do
    transaction = create_sortable_transaction("Mercado Central & Café", Date.new(2026, 8, 31), 42)
    transaction.update!(notes: "Weekly groceries")
    account = Account.create!(name: "Account name must stay hidden", kind: :bank)
    transaction.update!(account: account)
    expected_search_url = "https://www.google.com/search?q=Mercado+Central+%26+Caf%C3%A9+S%C3%A3o+jos%C3%A9+dos+campos"

    get transactions_path, params: { q: transaction.description }

    assert_response :success
    assert_select ".transaction-date strong", text: "Monday"
    assert_select ".transaction-date time[datetime='2026-08-31']", text: "31 Aug 2026"
    assert_select ".transaction-description small", text: transaction.notes
    assert_select ".transaction-description", text: /Account name must stay hidden/, count: 0
    assert_select "a.transaction-google-link[href='#{expected_search_url}'][target='_blank'][rel='noopener noreferrer']", count: 1 do
      assert_select "svg[aria-hidden='true']", count: 1
    end

    get edit_transaction_path(transaction)

    assert_response :success
    assert_select ".review-description", text: transaction.description
    assert_select ".review-date strong", text: "Monday"
    assert_select ".review-date span", text: "31 August 2026"
    assert_select "a.review-google-link[href='#{expected_search_url}'][target='_blank'][rel='noopener noreferrer']", count: 1 do
      assert_select "svg[aria-hidden='true']", count: 1
    end
  end

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

  private

  def create_sortable_transaction(description, date, amount)
    Transaction.create!(date: date, statement_month: date.beginning_of_month, description: description,
      amount: amount, direction: :outcome)
  end

  def transaction_names
    css_select(".transaction-description strong").map { |node| node.text.strip }
  end
end
