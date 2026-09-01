require "test_helper"

class CreditCardPaymentMatcherTest < ActiveSupport::TestCase
  include ActionDispatch::TestProcess::FixtureFile

  setup do
    @month = Date.new(2026, 8, 1)
    @bank_account = Account.create!(name: "Matcher checking", kind: :bank)
  end

  test "links the only same-month bank expense with the exact statement total" do
    payment = bank_payment("CARD PAYMENT", 199.99)
    statement = card_statement(199.99)

    CreditCardPaymentMatcher.call(statement)

    assert_equal payment, statement.reload.bank_payment_transaction
    assert_not_includes Transaction.reportable, payment
  end

  test "does not guess when more than one bank expense matches" do
    bank_payment("CARD PAYMENT ONE", 199.99)
    bank_payment("CARD PAYMENT TWO", 199.99)
    statement = card_statement(199.99)

    CreditCardPaymentMatcher.call(statement)

    assert_nil statement.reload.bank_payment_transaction
    assert_equal 2, statement.payment_candidates.count
  end

  test "matches an existing card statement when the bank statement is imported later" do
    statement = card_statement(199.99)
    payment = bank_payment("LATE CARD PAYMENT", 199.99)
    bank_import = create_import(:bank, "Late bank")

    CreditCardPaymentMatcher.call(bank_import)

    assert_equal payment, statement.reload.bank_payment_transaction
  end

  private

  def bank_payment(description, amount)
    Transaction.create!(account: @bank_account, transaction_kind: :bank, date: @month + 10.days,
      statement_month: @month, description: description, amount: amount, direction: :outcome)
  end

  def card_statement(total)
    create_import(:credit_card, "Matcher card").tap do |statement|
      statement.update!(statement_total: total, status: :completed)
    end
  end

  def create_import(kind, name)
    StatementImport.new(kind: kind, statement_month: @month, account_name: name).tap do |statement|
      statement.file.attach(fixture_file_upload("santander_bank.csv", "text/csv"))
      statement.save!
    end
  end
end
