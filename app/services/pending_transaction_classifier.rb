class PendingTransactionClassifier
  Summary = Data.define(:categorized, :not_identified)

  def initialize(transactions: Transaction.pending_categorization.includes(:category).order(:id))
    @transactions = transactions.to_a
  end

  def call
    return Summary.new(categorized: 0, not_identified: 0) if @transactions.empty?

    fallback = Category.not_identified!
    classifications = OpenaiTransactionClassifier.new(
      rows: @transactions.map { |transaction| classifier_row(transaction) },
      categories: Category.where.not(id: fallback.id).order(:name).to_a
    ).call
    categorized = 0
    not_identified = 0

    Transaction.transaction do
      @transactions.each do |transaction|
        result = classifications[transaction.id]
        if result&.category
          transaction.update!(category: result.category, category_confidence: result.confidence, categorization_status: :categorized)
          categorized += 1
        else
          transaction.update!(category: fallback, category_confidence: 0, categorization_status: :pending)
          not_identified += 1
        end
      end
    end

    Summary.new(categorized:, not_identified:)
  end

  private

  def classifier_row(transaction)
    {
      transaction_index: transaction.id,
      date: transaction.date,
      description: transaction.description,
      amount: transaction.amount,
      direction: transaction.direction
    }
  end
end
