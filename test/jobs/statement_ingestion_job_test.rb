require "test_helper"

class StatementIngestionJobTest < ActiveJob::TestCase
  include ActionDispatch::TestProcess::FixtureFile

  test "imports Santander rows atomically and remains idempotent" do
    statement_import = build_import

    without_model_matches { StatementIngestionJob.perform_now(statement_import.id) }

    statement_import.reload
    assert_predicate statement_import, :needs_review?
    assert_equal "not_available", statement_import.reconciliation_status
    assert_equal 3, statement_import.transactions.count
    assert_equal 3, statement_import.transactions.pending_categorization.count
    assert statement_import.transactions.all? { |transaction| transaction.category == Category.not_identified! }

    source_keys = statement_import.transactions.order(:source_key).pluck(:source_key)
    statement_import.update!(status: :failed)
    without_model_matches { StatementIngestionJob.perform_now(statement_import.id) }

    assert_equal 3, statement_import.transactions.count
    assert_equal source_keys, statement_import.transactions.order(:source_key).pluck(:source_key)
  end

  test "reuses a manually categorized Santander description" do
    account = Account.create!(name: "Santander checking", kind: :bank)
    food = Category.create!(name: "Job food", kind: :outcome)
    Transaction.create!(account: account, category: food, categorization_status: :categorized, date: Date.new(2026, 7, 1), statement_month: Date.new(2026, 7, 1), description: "COMPRA TEST MARKET", amount: 20, direction: :outcome)
    statement_import = build_import(account_name: account.name)

    without_model_matches { StatementIngestionJob.perform_now(statement_import.id) }

    matched = statement_import.transactions.where(description: "COMPRA TEST MARKET")
    assert_equal 2, matched.count
    assert matched.all?(&:categorization_categorized?)
    assert matched.all? { |transaction| transaction.category == food }
  end

  test "uses one model classification batch for descriptions without a saved pattern" do
    food = Category.create!(name: "AI food", kind: :outcome)
    statement_import = build_import
    classifier = Object.new
    classifier.define_singleton_method(:call) do
      {
        1 => OpenaiTransactionClassifier::Result.new(category: food, confidence: BigDecimal("0.91")),
        2 => OpenaiTransactionClassifier::Result.new(category: food, confidence: BigDecimal("0.88"))
      }
    end

    OpenaiTransactionClassifier.stub(:new, ->(*) { classifier }) do
      StatementIngestionJob.perform_now(statement_import.id)
    end

    purchases = statement_import.transactions.where(description: "COMPRA TEST MARKET")
    assert_equal 2, purchases.count
    assert purchases.all?(&:categorization_categorized?)
    assert purchases.all? { |transaction| transaction.category == food }
    unrecognized = statement_import.transactions.find_by!(description: "PIX RECEBIDO TEST CUSTOMER")
    assert_predicate unrecognized, :categorization_pending?
    assert_equal Category.not_identified!, unrecognized.category
  end

  private

  def without_model_matches(&block)
    classifier = Object.new
    classifier.define_singleton_method(:call) { {} }
    OpenaiTransactionClassifier.stub(:new, ->(*) { classifier }, &block)
  end

  def build_import(account_name: "Santander checking")
    statement_import = StatementImport.new(kind: :bank, statement_month: Date.new(2026, 8, 1), account_name: account_name)
    statement_import.file.attach(fixture_file_upload("santander_bank.csv", "text/csv"))
    statement_import.save!
    statement_import
  end
end
