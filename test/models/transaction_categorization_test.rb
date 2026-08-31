require "test_helper"

class TransactionCategorizationTest < ActiveSupport::TestCase
  setup do
    @old_category = Category.create!(name: "Previous category", kind: :outcome)
    @new_category = Category.create!(name: "New category", kind: :outcome)
    @transaction = create_entry(category: @old_category, categorization_status: :categorized)
  end

  test "category changes update identical descriptions across all statement months and accounts" do
    account = Account.create!(name: "Another account", kind: :bank)
    matches = (1..12).map do |month|
      create_entry(statement_month: Date.new(2026, month, 1), amount: month,
        account: account, category: @old_category, notes: "Keep note #{month}")
    end
    before_attributes = matches.map { |entry| entry.attributes.except("category_id", "category_confidence", "categorization_status", "updated_at") }

    assert @transaction.update_categorization(category_id: @new_category.id, notes: "Edited note")

    matches.each_with_index do |entry, index|
      entry.reload
      assert_equal @new_category, entry.category
      assert_predicate entry, :categorization_categorized?
      assert_equal BigDecimal("1"), entry.category_confidence
      assert_equal before_attributes[index], entry.attributes.except("category_id", "category_confidence", "categorization_status", "updated_at")
    end
    assert_equal "Edited note", @transaction.reload.notes
  end

  test "first category assignment also categorizes matching pending entries" do
    @transaction.update!(category: nil, categorization_status: :pending)
    match = create_entry(statement_month: Date.new(2026, 2, 1))

    assert @transaction.update_categorization(category_id: @new_category.id)

    assert_equal @new_category, match.reload.category
    assert_predicate match, :categorization_categorized?
  end

  test "uses statement year rather than transaction date and excludes other years" do
    @transaction.update!(date: Date.new(2025, 12, 31))
    match = create_entry(date: Date.new(2027, 1, 1), statement_month: Date.new(2026, 12, 1))
    excluded = [Date.new(2025, 12, 1), Date.new(2027, 1, 1)].map do |month|
      create_entry(statement_month: month)
    end

    assert @transaction.update_categorization(category_id: @new_category.id)

    assert_equal @new_category, match.reload.category
    excluded.each { |entry| assert_nil entry.reload.category }
  end

  test "requires exact description and same direction even for a category supporting both directions" do
    both = Category.create!(name: "Both directions", kind: :both)
    excluded = [
      create_entry(description: "PIX 654321 Test Store"),
      create_entry(description: "pix 123456 test store"),
      create_entry(description: "PIX 123456 Test Store extra"),
      create_entry(direction: :income)
    ]
    assert_equal @transaction.merchant_key, excluded.first.merchant_key

    assert @transaction.update_categorization(category_id: both.id)

    excluded.each { |entry| assert_nil entry.reload.category }
  end

  test "notes only and unchanged category saves do not propagate" do
    match = create_entry(category: @new_category)
    original = match.attributes

    assert @transaction.update_categorization(notes: "Only this note")
    assert_equal original, match.reload.attributes
    assert @transaction.update_categorization(category_id: @old_category.id, notes: "Updated note")
    assert_equal original, match.reload.attributes
  end

  test "invalid edits leave both the edited transaction and its matches unchanged" do
    match = create_entry
    originals = [@transaction.attributes, match.attributes]
    income = Category.create!(name: "Income only", kind: :income)

    [income.id, ""].each do |category_id|
      assert_not @transaction.update_categorization(category_id: category_id, notes: "Invalid edit")
      assert_predicate @transaction.errors, :present?
      assert_equal originals, [@transaction.reload.attributes, match.reload.attributes]
    end
  end

  test "ordinary updates do not propagate automated categorization" do
    match = create_entry

    @transaction.update!(category: @new_category)

    assert_nil match.reload.category
  end

  private

  def create_entry(**attributes)
    Transaction.create!({
      date: Date.new(2026, 8, 15),
      statement_month: Date.new(2026, 8, 1),
      description: "PIX 123456 Test Store",
      amount: 10,
      direction: :outcome
    }.merge(attributes))
  end
end
