require "test_helper"

class ImportsControllerTest < ActionDispatch::IntegrationTest
  test "import routes expose only supported actions" do
    assert_equal "/imports/42", import_path(42)
    assert_equal "/imports/42/edit", edit_import_path(42)
    assert_equal "/imports/42/process_file", process_file_import_path(42)
    assert_equal "/imports/month", month_imports_path
    assert_equal({ controller: "imports", action: "update", id: "42" }, Rails.application.routes.recognize_path("/imports/42", method: :patch).symbolize_keys)
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("/transactions/42", method: :get)
    end
  end

  test "primary pages render without missing actions or templates" do
    get root_path
    assert_response :success
    get imports_path
    assert_response :success
    get new_import_path
    assert_response :success
    get transactions_path
    assert_response :success
    get categories_path
    assert_response :success
    get reports_path
    assert_response :success
  end

  test "an invalid statement month returns validation errors instead of raising" do
    post imports_path, params: { statement_import: { kind: "bank", statement_month: "2026-13", account_name: "Santander" } }

    assert_response :unprocessable_entity
  end

  test "a failed import month can be corrected and processed again" do
    statement_import = create_import
    statement_import.update!(status: :failed, error_message: "The statement did not match this month")

    get import_path(statement_import)

    assert_response :success
    assert_select "a[href='#{edit_import_path(statement_import)}']", text: "Edit month"

    get edit_import_path(statement_import)

    assert_response :success
    assert_select "form[action='#{import_path(statement_import)}'][method='post']" do
      assert_select "input[name='_method'][value='patch']"
      assert_select "input[name='statement_import[statement_month]'][type='month'][value='2026-08']"
      assert_select "input[type='submit'][value='Update month']"
    end

    patch import_path(statement_import), params: { statement_import: { statement_month: "2026-09" } }

    assert_redirected_to import_path(statement_import)
    statement_import.reload
    assert_equal Date.new(2026, 9, 1), statement_import.statement_month
    assert_predicate statement_import, :pending?
    assert_nil statement_import.error_message
  end

  test "an import month cannot be changed after processing" do
    statement_import = create_import
    statement_import.update!(status: :completed)

    get import_path(statement_import)
    assert_response :success
    assert_select "a[href='#{edit_import_path(statement_import)}']", count: 0

    get edit_import_path(statement_import)
    assert_redirected_to import_path(statement_import)

    patch import_path(statement_import), params: { statement_import: { statement_month: "2026-09" } }

    assert_redirected_to import_path(statement_import)
    assert_equal Date.new(2026, 8, 1), statement_import.reload.statement_month
  end

  test "a duplicate import month displays the validation error" do
    august_import = create_import
    september_import = create_import(month: Date.new(2026, 9, 1))

    patch import_path(september_import), params: { statement_import: { statement_month: "2026-08" } }

    assert_response :unprocessable_entity
    assert_select ".form-error", text: /already been imported for this month/
    assert_equal Date.new(2026, 9, 1), september_import.reload.statement_month
    assert StatementImport.exists?(august_import.id)
  end

  test "deleting an import removes its transactions and allows the file to be uploaded again" do
    statement_import = create_import
    transaction = create_transaction(statement_import)

    get import_path(statement_import)
    assert_response :success
    assert_select "form[action='#{import_path(statement_import)}'] button", text: "Delete this import"
    assert_select "form[action='#{month_imports_path(month: '2026-08')}'] button", text: "Clear entire month"
    assert_select ".danger-action-row", count: 2
    assert_select "button[aria-describedby='delete-import-description']", text: "Delete this import"
    assert_select "button[aria-describedby='clear-month-description']", text: "Clear entire month"
    assert_select "#clear-month-description", text: /August 2026/
    assert_select ".danger-action-row form[data-turbo-confirm]", count: 2

    assert_difference -> { StatementImport.count }, -1 do
      assert_difference -> { Transaction.count }, -1 do
        delete import_path(statement_import)
      end
    end

    assert_redirected_to imports_path
    assert_not StatementImport.exists?(statement_import.id)
    assert_not Transaction.exists?(transaction.id)

    replacement = build_import
    assert replacement.save, replacement.errors.full_messages.to_sentence
  end

  test "clearing a month removes every import and transaction only in that month" do
    august_import = create_import
    august_import.update_column(:source_digest, "august-second-file")
    second_august_import = create_import
    august_orphan = create_transaction(nil)
    september_import = create_import(month: Date.new(2026, 9, 1))
    september_transaction = create_transaction(september_import, month: Date.new(2026, 9, 1))

    delete month_imports_path, params: { month: "2026-08" }

    assert_redirected_to imports_path
    assert_not StatementImport.exists?(august_import.id)
    assert_not StatementImport.exists?(second_august_import.id)
    assert_not Transaction.exists?(august_orphan.id)
    assert StatementImport.exists?(september_import.id)
    assert Transaction.exists?(september_transaction.id)
  end

  test "a processing import cannot be deleted or cleared with its month" do
    statement_import = create_import
    statement_import.update!(status: :processing)

    assert_no_difference -> { StatementImport.count } do
      delete import_path(statement_import)
    end
    assert_redirected_to import_path(statement_import)

    assert_no_difference -> { StatementImport.count } do
      delete month_imports_path, params: { month: "2026-08" }
    end
    assert_redirected_to imports_path
  end

  private

  def build_import(month: Date.new(2026, 8, 1))
    StatementImport.new(kind: :bank, statement_month: month, account_name: "Santander").tap do |statement_import|
      statement_import.file.attach(fixture_file_upload("santander_bank.csv", "text/csv"))
    end
  end

  def create_import(month: Date.new(2026, 8, 1))
    build_import(month: month).tap(&:save!)
  end

  def create_transaction(statement_import, month: Date.new(2026, 8, 1))
    Transaction.create!(
      statement_import: statement_import,
      date: month,
      statement_month: month,
      description: "Test transaction",
      amount: 10,
      direction: :outcome
    )
  end
end
