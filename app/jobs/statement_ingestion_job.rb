require "digest"

class StatementIngestionJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: :polynomially_longer, attempts: 3
  discard_on StatementParser::ParseError

  def perform(import_id)
    import = StatementImport.find(import_id)
    claimed = import.with_lock do
      next false unless import.pending? || import.failed?

      import.update!(status: :processing, error_message: nil)
      true
    end
    return unless claimed

    parser = StatementParser.new(import)
    rows = parser.call
    raise StatementParser::ParseError, "No transactions were found in the Santander statement" if rows.empty?

    account = Account.find_or_create_by!(name: import.account_name.presence || import.kind.humanize, kind: import.kind)
    import.update!(account: account)
    prepared_rows = prepare_rows(rows)
    matches = category_matches(import, account, prepared_rows)

    StatementImport.transaction do
      import.lock!
      source_keys = prepared_rows.map do |prepared|
        persist_transaction(import, prepared.fetch(:row), prepared.fetch(:source_key), matches.fetch(prepared.fetch(:source_key)))
      end
      import.transactions.where.not(source_key: source_keys).destroy_all

      normalized = normalized_total(rows)
      statement_total = parser.statement_total
      reconciliation = reconciliation_status(statement_total, normalized)
      import.update!(
        statement_total: statement_total,
        normalized_total: normalized,
        reconciliation_difference: statement_total ? normalized - statement_total : nil,
        reconciliation_status: reconciliation,
        status: import.transactions.pending_categorization.exists? || reconciliation == "mismatched" ? :needs_review : :completed
      )
    end
  rescue StandardError => e
    import&.update(status: :failed, error_message: e.message.to_s.truncate(1_000))
    Rails.logger.error(e.full_message)
    raise
  end

  private

  def prepare_rows(rows)
    occurrences = Hash.new(0)
    rows.map.with_index do |row, transaction_index|
      signature = [row.fetch("date"), row.fetch("description"), row.fetch("amount").to_s("F"), row.fetch("direction")].join("|")
      occurrence = occurrences[signature]
      occurrences[signature] += 1
      {
        row: row,
        transaction_index: transaction_index,
        source_key: Digest::SHA256.hexdigest("#{signature}|#{occurrence}")
      }
    end
  end

  def category_matches(import, account, prepared_rows)
    fallback = Category.not_identified!
    existing = import.transactions.where(source_key: prepared_rows.pluck(:source_key)).index_by(&:source_key)
    matches = {}
    unknown = []

    prepared_rows.each do |prepared|
      transaction = existing[prepared.fetch(:source_key)]
      if transaction&.categorization_categorized?
        matches[prepared.fetch(:source_key)] = CategoryMatcher::Match.new(category: transaction.category, confidence: transaction.category_confidence)
        next
      end

      row = prepared.fetch(:row)
      match = CategoryMatcher.new(description: row.fetch("description"), direction: row.fetch("direction"), account: account).call
      if match.category
        matches[prepared.fetch(:source_key)] = match
      else
        unknown << prepared
      end
    end

    classifications = OpenaiTransactionClassifier.new(
      rows: unknown.map { |prepared| classifier_row(prepared) },
      categories: Category.where.not(id: fallback.id).order(:name).to_a
    ).call

    unknown.each do |prepared|
      result = classifications[prepared.fetch(:transaction_index)]
      matches[prepared.fetch(:source_key)] = result&.category ? result : OpenaiTransactionClassifier::Result.new(category: fallback, confidence: BigDecimal("0"))
    end
    matches
  end

  def classifier_row(prepared)
    row = prepared.fetch(:row)
    {
      transaction_index: prepared.fetch(:transaction_index),
      date: row.fetch("date"),
      description: row.fetch("description"),
      amount: row.fetch("amount"),
      direction: row.fetch("direction")
    }
  end

  def persist_transaction(import, row, source_key, match)
    transaction = import.transactions.find_or_initialize_by(source_key: source_key)

    transaction.assign_attributes(
      account: import.account,
      date: row["date"],
      statement_month: import.statement_month,
      description: row["description"],
      amount: row["amount"],
      direction: row["direction"],
      currency: row["currency"].presence || "BRL"
    )
    unless transaction.categorization_categorized?
      transaction.assign_attributes(
        category: match.category,
        category_confidence: match.confidence,
        categorization_status: match.category.name == Category::NOT_IDENTIFIED_NAME && match.category.parent_id.nil? ? :pending : :categorized
      )
    end
    transaction.save!
    source_key
  end

  def normalized_total(rows)
    rows.sum { |row| row["direction"] == "income" ? -row["amount"].to_d : row["amount"].to_d }
  end

  def reconciliation_status(statement_total, normalized_total)
    return "not_available" unless statement_total

    (normalized_total - statement_total).abs <= BigDecimal("0.01") ? "matched" : "mismatched"
  end
end
