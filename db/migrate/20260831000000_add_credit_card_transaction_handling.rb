class AddCreditCardTransactionHandling < ActiveRecord::Migration[7.2]
  def change
    add_column :transactions, :transaction_kind, :string, null: false, default: "bank"
    add_check_constraint :transactions,
      "transaction_kind IN ('bank', 'credit_card')",
      name: "transactions_kind_check"
    add_index :transactions, %i[transaction_kind statement_month], name: "index_transactions_on_kind_and_statement_month"

    add_reference :statement_imports,
      :bank_payment_transaction,
      foreign_key: { to_table: :transactions, on_delete: :nullify },
      index: { unique: true }
  end
end
