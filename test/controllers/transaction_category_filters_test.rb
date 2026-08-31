require "test_helper"

class TransactionCategoryFiltersTest < ActionDispatch::IntegrationTest
  setup do
    @parent = Category.create!(name: "Food", kind: :outcome)
    @child = Category.create!(name: "Groceries", kind: :outcome, parent: @parent)
    @grandchild = Category.create!(name: "Produce", kind: :outcome, parent: @child)
    @other = Category.create!(name: "Travel", kind: :outcome)
    @parent_entry = create_entry("Market parent", @parent)
    @child_entry = create_entry("Market groceries", @child)
    @grandchild_entry = create_entry("Market produce", @grandchild, status: :pending)
    @other_entry = create_entry("Market travel", @other)
    @july_entry = create_entry("Market July", @child, month: Date.new(2026, 7, 1))
    @unrelated = create_entry("Bakery", @child)
    @uncategorized = create_entry("Market unassigned", nil, status: :pending)
  end

  test "parent filter renders its own entries and descendants and checks the selected option" do
    get transactions_path, params: { month: "2026-08", category_ids: [@parent.id] }

    assert_response :success
    assert_entries @parent_entry, @child_entry, @grandchild_entry, @unrelated
    assert_select "#filter-category-#{@parent.id}[checked]"
    assert_select "#filter-category-#{@child.id}[checked]", count: 0
    assert_select "label[for='filter-category-#{@parent.id}'] small", text: "Includes subcategories"
    assert_select ".category-filter summary", text: "Categories (1)"
    assert_select "input[name='category_ids[]'][type='hidden'][value='']"
  end

  test "selecting multiple categories includes either selection without duplicate rows" do
    get transactions_path, params: { month: "2026-08", category_ids: [@child.id, @grandchild.id, @other.id] }

    assert_entries @child_entry, @grandchild_entry, @unrelated, @other_entry
    [@child, @grandchild, @other].each { |category| assert_select "#filter-category-#{category.id}[checked]" }
    assert_select ".category-filter summary", text: "Categories (3)"
  end

  test "category month search and review filters all intersect" do
    @july_entry.update!(date: Date.new(2026, 8, 15))
    get transactions_path, params: { month: "2026-08", q: "MARKET", category_ids: [@parent.id], status: "review" }

    assert_entries @grandchild_entry
    assert_select "#transaction-search[value='MARKET']"
    assert_select "#workspace-month[value='2026-08']"
    assert_select ".transaction-search input[name='status'][value='review']"

    get transactions_path, params: { status: "" }
    assert_entries @parent_entry, @child_entry, @grandchild_entry
  end

  test "category selection survives month changes all months navigation and category save redirects" do
    get transactions_path, params: { month: "2026-08", q: "Market", category_ids: [@child.id] }
    get transactions_path, params: { month: "2026-07" }
    assert_entries @july_entry

    get transactions_path, params: { month: "all" }
    assert_entries @child_entry, @grandchild_entry, @july_entry

    get categories_path
    get transactions_path
    assert_entries @child_entry, @grandchild_entry, @july_entry
    assert_select "#filter-category-#{@child.id}[checked]"

    patch transaction_path(@child_entry), params: { transaction: { category_id: @child.id, notes: "Updated" } }
    follow_redirect!
    assert_entries @child_entry, @grandchild_entry, @july_entry
    assert_select "#filter-category-#{@child.id}[checked]"
  end

  test "clear search preserves category month and review filters" do
    bakery = create_entry("Bakery pending", @grandchild, status: :pending)
    get transactions_path, params: { month: "2026-08", q: "Market", category_ids: [@parent.id], status: "review" }
    clear_link = css_select(".transaction-search a").find { |link| link.text == "Clear search" }

    get clear_link["href"]

    assert_entries @grandchild_entry, bakery
    assert_select "#filter-category-#{@parent.id}[checked]"
    assert_select "#workspace-month[value='2026-08']"
    assert_select "#transaction-search[value='']"
  end

  test "clear categories preserves month search and review filters" do
    get transactions_path, params: { month: "2026-08", q: "Market", category_ids: [@parent.id], status: "review" }
    clear_link = css_select(".category-filter-active a").first

    get clear_link["href"]

    assert_entries @grandchild_entry, @uncategorized
    assert_select ".category-filter input[checked]", count: 0
    assert_select "#workspace-month[value='2026-08']"
    assert_select "#transaction-search[value='Market']"
  end

  test "applying all checkboxes unchecked clears persisted selection" do
    get transactions_path, params: { month: "2026-08", category_ids: [@parent.id] }
    get transactions_path, params: { category_ids: [""] }

    assert_entries @parent_entry, @child_entry, @grandchild_entry, @other_entry, @unrelated, @uncategorized
    assert_select ".category-filter-active", count: 0
    get transactions_path
    assert_select ".category-filter input[checked]", count: 0
  end

  test "invalid duplicate and deleted categories are safely removed from the selection" do
    get transactions_path, params: { month: "2026-08", category_ids: ["", @child.id.to_s, @child.id.to_s, "invalid", "#{@other.id}junk", "-1", (Category.maximum(:id) + 1).to_s] }
    assert_entries @child_entry, @grandchild_entry, @unrelated
    assert_select ".category-filter summary", text: "Categories (1)"

    [{ bad: @other.id }, "invalid"].each do |selection|
      get transactions_path, params: { category_ids: selection }
      assert_response :success
      assert_select ".category-filter input[checked]", count: 0
    end

    unused = Category.create!(name: "Unused", kind: :both)
    get transactions_path, params: { category_ids: [unused.id] }
    unused.destroy!
    get transactions_path
    assert_response :success
    assert_select ".category-filter-active", count: 0
  end

  test "no matching entries show helpful empty state without losing selection" do
    get transactions_path, params: { month: "2026-08", q: "no such entry", category_ids: [@parent.id] }

    assert_entries
    assert_select ".empty-state strong", text: "No matching transactions."
    assert_select ".empty-state p", text: /categories/
    assert_select "#filter-category-#{@parent.id}[checked]"
  end

  private

  def create_entry(description, category, month: Date.new(2026, 8, 1), status: :categorized)
    Transaction.create!(date: month, statement_month: month, description: description,
      amount: 10, direction: :outcome, category: category, categorization_status: status)
  end

  def assert_entries(*entries)
    assert_equal entries.map(&:description).sort, css_select(".transaction-description strong").map(&:text).sort
  end
end
