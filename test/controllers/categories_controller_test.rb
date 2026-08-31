require "test_helper"

class CategoriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @unused = Category.create!(name: "Unused", kind: :both)
    @used = Category.create!(name: "Used", kind: :outcome)
    @transaction = Transaction.create!(date: Date.new(2026, 7, 1), statement_month: Date.new(2026, 7, 1),
      description: "Groceries", amount: 10, direction: :outcome, category: @used)
    @parent = Category.create!(name: "Parent", kind: :both)
    @child = Category.create!(name: "Child", kind: :both, parent: @parent)
  end

  test "page offers confirmed deletion only for empty categories regardless of selected month" do
    get categories_path, params: { month: "2026-08" }

    assert_response :success
    [@unused, @child].each do |category|
      assert_select "form[action='#{category_path(category)}'][data-turbo-confirm]" do
        assert_select "input[name='_method'][value='delete']"
        assert_select "button[aria-label='Delete #{category.name}']", text: "Delete"
      end
    end
    [@used, @parent].each do |category|
      assert_select "form[action='#{category_path(category)}']", count: 0
    end
    assert_select ".tree-kind", text: "Has transactions"
    assert_select ".tree-kind", text: "Has subcategories"
  end

  test "deletes an unused category" do
    assert_difference "Category.count", -1 do
      delete category_path(@unused)
    end

    assert_redirected_to categories_path
    assert_equal "Category removed.", flash[:notice]
  end

  test "direct delete request cannot delete a category with transactions" do
    get categories_path, params: { month: "2026-08" }

    assert_no_difference ["Category.count", "Transaction.count"] do
      delete category_path(@used)
    end

    assert_redirected_to categories_path
    assert_includes flash[:alert], "transactions"
    assert_equal @used.id, @transaction.reload.category_id
    follow_redirect!
    assert_select ".flash.form-error", text: /transactions/
  end

  test "direct delete request cannot delete a category with subcategories" do
    assert_no_difference "Category.count" do
      delete category_path(@parent)
    end

    assert_redirected_to categories_path
    assert flash[:alert].present?
    assert_equal @parent.id, @child.reload.parent_id
  end
end
