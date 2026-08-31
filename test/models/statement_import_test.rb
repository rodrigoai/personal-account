require "test_helper"

class StatementImportTest < ActiveSupport::TestCase
  include ActionDispatch::TestProcess::FixtureFile

  test "normalizes the month and fingerprints the upload" do
    statement_import = StatementImport.new(kind: :bank, statement_month: Date.new(2026, 8, 20), account_name: "Santander")
    statement_import.file.attach(fixture_file_upload("santander_bank.csv", "text/csv"))

    assert statement_import.valid?
    assert_equal Date.new(2026, 8, 1), statement_import.statement_month
    assert_predicate statement_import.source_digest, :present?
  end

  test "rejects a disguised executable" do
    statement_import = StatementImport.new(kind: :bank, statement_month: Date.new(2026, 8, 1))
    statement_import.file.attach(io: StringIO.new("\x7FELFnot a statement"), filename: "statement.csv", content_type: "application/octet-stream")

    assert_not statement_import.valid?
    assert_includes statement_import.errors[:file], "must be a PDF, CSV, XLS, or XLSX file"
  end

  test "rejects the same statement file for the same month and kind" do
    first = StatementImport.new(kind: :bank, statement_month: Date.new(2026, 8, 1))
    first.file.attach(fixture_file_upload("santander_bank.csv", "text/csv"))
    first.save!
    duplicate = StatementImport.new(kind: :bank, statement_month: Date.new(2026, 8, 1))
    duplicate.file.attach(fixture_file_upload("santander_bank.csv", "text/csv"))

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:source_digest], "has already been imported for this month"
  end
end
