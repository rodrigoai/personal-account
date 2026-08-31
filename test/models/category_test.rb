require "test_helper"

class CategoryTest < ActiveSupport::TestCase
  test "deletes a category without transactions or children" do
    category = Category.create!(name: "Unused", kind: :both)

    assert_difference "Category.count", -1 do
      assert category.destroy
    end
  end

  test "does not delete a category or unlink its transactions" do
    category = Category.create!(name: "Used", kind: :outcome)
    transaction = Transaction.create!(date: Date.new(2026, 7, 1), statement_month: Date.new(2026, 7, 1),
      description: "Groceries", amount: 10, direction: :outcome, category: category)

    assert_no_difference ["Category.count", "Transaction.count"] do
      assert_not category.destroy
    end
    assert_equal category.id, transaction.reload.category_id
    assert_includes category.errors.full_messages.to_sentence, "transactions"
  end

  test "does not delete a category with children" do
    parent = Category.create!(name: "Parent", kind: :both)
    child = Category.create!(name: "Child", kind: :both, parent: parent)

    assert_no_difference "Category.count" do
      assert_not parent.destroy
    end
    assert_equal parent.id, child.reload.parent_id
  end

  test "rejects category cycles" do
    parent = Category.create!(name: "Parent", kind: :both)
    child = Category.create!(name: "Child", kind: :both, parent: parent)

    parent.parent = child

    assert_not parent.valid?
    assert_includes parent.errors[:parent], "cannot create a category cycle"
  end
end
