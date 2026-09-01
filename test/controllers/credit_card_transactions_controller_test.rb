require "test_helper"

class CreditCardTransactionsControllerTest < ActionDispatch::IntegrationTest
  include ActionDispatch::TestProcess::FixtureFile

  setup do
    @month = Date.current.beginning_of_month
    @bank = create_transaction("Bank purchase", :bank)
    @card = create_transaction("Card purchase", :credit_card)
  end

  test "bank and credit-card entries have separate ledger pages" do
    get transactions_path
    assert_response :success
    assert_select "h1", text: "Transactions"
    assert_select ".transaction-description strong", text: @bank.description
    assert_select ".transaction-description strong", text: @card.description, count: 0

    get credit_card_transactions_path
    assert_response :success
    assert_select "h1", text: "Credit-card transactions"
    assert_select ".transaction-description strong", text: @card.description
    assert_select ".transaction-description strong", text: @bank.description, count: 0
  end

  test "credit-card entries use the requested ordering" do
    older = create_transaction("Card sort Zebra", :credit_card)
    older.update!(date: @month + 1.day, amount: 10)
    newer = create_transaction("Card sort Alpha", :credit_card)
    newer.update!(date: @month + 2.days, amount: 20)

    get credit_card_transactions_path, params: { q: "card sort", sort: "name", direction: "asc" }

    assert_response :success
    assert_equal [newer.description, older.description], css_select(".transaction-description strong").map { |node| node.text.strip }
  end

  test "shows and searches by installment" do
    @card.update!(installment: "01/12")

    get credit_card_transactions_path, params: { q: "01/12" }

    assert_response :success
    assert_select ".transaction-description strong", text: @card.description
    assert_select ".transaction-description small", text: "Installment 01/12"
  end

  test "manual reconciliation links and unlinks an eligible bank payment" do
    statement = StatementImport.new(kind: :credit_card, statement_month: @month, account_name: "Controller card",
      statement_total: @bank.amount, status: :completed)
    statement.file.attach(fixture_file_upload("santander_bank.csv", "text/csv"))
    statement.save!

    patch payment_import_path(statement), params: { bank_payment_transaction_id: @bank.id }
    assert_redirected_to import_path(statement)
    assert_equal @bank, statement.reload.bank_payment_transaction

    patch payment_import_path(statement), params: { bank_payment_transaction_id: "" }
    assert_redirected_to import_path(statement)
    assert_nil statement.reload.bank_payment_transaction
  end

  private

  def create_transaction(description, kind)
    Transaction.create!(date: @month, statement_month: @month, description: description,
      amount: 25, direction: :outcome, transaction_kind: kind)
  end
end
