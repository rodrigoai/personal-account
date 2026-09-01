class CreditCardTransactionsController < TransactionsController
  private

  def transaction_scope
    Transaction.transaction_kind_credit_card
  end

  def search_session_key
    :credit_card_transaction_search
  end

  def category_session_key
    :credit_card_transaction_category_ids
  end

  def transaction_index_path
    credit_card_transactions_path
  end

  def transaction_page_title
    "Credit-card transactions"
  end

  def transaction_page_description
    "Detailed card purchases, classified independently from their bank payment."
  end
end
