require "test_helper"

class TransactionCategoryFilterTest < ActiveSupport::TestCase
  setup do
    @parent = Category.create!(name: "Food", kind: :outcome)
    @child = Category.create!(name: "Groceries", kind: :outcome, parent: @parent)
    @grandchild = Category.create!(name: "Produce", kind: :outcome, parent: @child)
    @sibling = Category.create!(name: "Restaurants", kind: :outcome, parent: @parent)
    @other = Category.create!(name: "Travel", kind: :outcome)
    @entries = [@parent, @child, @grandchild, @sibling, @other, nil].map do |category|
      Transaction.create!(date: Date.new(2026, 8, 1), statement_month: Date.new(2026, 8, 1),
        description: category&.name || "Uncategorized", amount: 10, direction: :outcome, category: category)
    end
  end

  test "parent includes itself and every descendant but not unrelated or uncategorized entries" do
    assert_equal @entries.first(4).map(&:id).sort, Transaction.in_categories([@parent.id]).pluck(:id).sort
  end

  test "child includes its descendants but not its parent or siblings" do
    assert_equal @entries.values_at(1, 2).map(&:id).sort, Transaction.in_categories([@child.id]).pluck(:id).sort
  end

  test "multiple categories are combined as a union without duplicate transactions" do
    ids = [@child.id, @grandchild.id, @other.id, @child.id]
    assert_equal @entries.values_at(1, 2, 4).map(&:id).sort, Transaction.in_categories(ids).pluck(:id).sort
  end

  test "empty selection removes the category restriction" do
    assert_equal Transaction.count, Transaction.in_categories([]).count
    assert_equal Transaction.count, Transaction.in_categories(nil).count
  end

  test "a nonexistent category matches no entries" do
    assert_empty Transaction.in_categories([Category.maximum(:id) + 1])
  end

  test "category filter composes with month search and review scopes" do
    selected = @entries[2]
    selected.update!(notes: "Weekly shopping")
    @entries[1].update!(statement_month: Date.new(2026, 7, 1), notes: "Weekly shopping")
    @entries[3].update!(notes: "Weekly shopping", categorization_status: :categorized)
    @entries[4].update!(notes: "Weekly shopping")

    matches = Transaction.for_month(Date.new(2026, 8, 1)).search("weekly").in_categories([@parent.id]).pending_categorization

    assert_equal [selected.id], matches.pluck(:id)
  end
end
