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
end
