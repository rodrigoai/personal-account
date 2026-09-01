class CreditCardPaymentMatcher
  def self.call(statement_import)
    new(statement_import).call
  end

  def initialize(statement_import)
    @statement_import = statement_import
  end

  def call
    relevant_statements.each do |card_statement|
      next if card_statement.bank_payment_transaction_id? || card_statement.statement_total.blank?

      candidates = card_statement.payment_candidates.limit(2).to_a
      card_statement.update!(bank_payment_transaction: candidates.first) if candidates.one?
    end
  end

  private

  attr_reader :statement_import

  def relevant_statements
    if statement_import.credit_card?
      StatementImport.where(id: statement_import.id)
    else
      StatementImport.credit_card
        .where(statement_month: statement_import.statement_month, bank_payment_transaction_id: nil)
        .where(status: %w[needs_review completed])
    end
  end
end
