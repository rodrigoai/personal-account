class HardenFinancialData < ActiveRecord::Migration[7.2]
  class LegacyTransaction < ActiveRecord::Base
    self.table_name = "transactions"
  end

  def up
    add_column :statement_imports, :source_digest, :string
    add_column :statement_imports, :error_message, :text
    add_index :statement_imports, %i[source_digest kind statement_month],
      unique: true,
      where: "source_digest IS NOT NULL",
      name: "index_statement_imports_on_unique_source"

    rename_column :transactions, :confidence, :category_confidence
    add_column :transactions, :categorization_status, :string, default: "pending", null: false
    add_column :transactions, :merchant_key, :string
    add_column :transactions, :source_key, :string

    execute <<~SQL
      UPDATE transactions
      SET category_id = NULL
      WHERE category_id IN (SELECT id FROM categories WHERE LOWER(name) = 'uncategorized');

      DELETE FROM categories WHERE LOWER(name) = 'uncategorized';

      UPDATE transactions
      SET categorization_status = CASE WHEN category_id IS NULL THEN 'pending' ELSE 'categorized' END,
          source_key = 'legacy-' || id,
          currency = COALESCE(currency, 'BRL');
    SQL

    LegacyTransaction.reset_column_information
    LegacyTransaction.find_each do |transaction|
      key = I18n.transliterate(transaction.description.to_s)
        .upcase
        .gsub(/\b\d{6,}\b/, " ")
        .gsub(/[^A-Z0-9]+/, " ")
        .squish
      transaction.update_columns(merchant_key: key)
    end

    change_column_null :transactions, :source_key, false
    change_column_null :transactions, :currency, false
    remove_column :transactions, :conciliated, :boolean

    deduplicate_accounts
    add_index :accounts, %i[name kind], unique: true
    add_index :categories, %i[parent_id name], unique: true, nulls_not_distinct: true
    add_index :transactions, %i[statement_import_id source_key], unique: true,
      where: "statement_import_id IS NOT NULL",
      name: "index_transactions_on_import_and_source_key"
    add_index :transactions, %i[account_id direction merchant_key],
      name: "index_transactions_for_category_matching"
    add_index :transactions, %i[statement_month direction]
    add_index :transactions, :categorization_status

    add_check_constraint :accounts, "kind IN ('bank', 'credit_card')", name: "accounts_kind_check"
    add_check_constraint :categories, "kind IN ('income', 'outcome', 'both')", name: "categories_kind_check"
    add_check_constraint :categories, "parent_id IS NULL OR parent_id <> id", name: "categories_parent_not_self_check"
    add_check_constraint :statement_imports,
      "kind IN ('bank', 'credit_card')",
      name: "statement_imports_kind_check"
    add_check_constraint :statement_imports,
      "status IN ('pending', 'processing', 'needs_review', 'completed', 'failed')",
      name: "statement_imports_status_check"
    add_check_constraint :statement_imports,
      "reconciliation_status IS NULL OR reconciliation_status IN ('not_available', 'matched', 'mismatched')",
      name: "statement_imports_reconciliation_status_check"
    add_check_constraint :transactions, "direction IN ('income', 'outcome')", name: "transactions_direction_check"
    add_check_constraint :transactions, "categorization_status IN ('pending', 'categorized')", name: "transactions_categorization_status_check"
    add_check_constraint :transactions, "amount > 0", name: "transactions_positive_amount_check"
    add_check_constraint :transactions,
      "category_confidence IS NULL OR category_confidence BETWEEN 0 AND 1",
      name: "transactions_category_confidence_check"

    remove_foreign_key :transactions, :statement_imports
    add_foreign_key :transactions, :statement_imports, on_delete: :cascade
  end

  def down
    remove_foreign_key :transactions, :statement_imports
    add_foreign_key :transactions, :statement_imports

    remove_check_constraint :transactions, name: "transactions_category_confidence_check"
    remove_check_constraint :transactions, name: "transactions_positive_amount_check"
    remove_check_constraint :transactions, name: "transactions_categorization_status_check"
    remove_check_constraint :transactions, name: "transactions_direction_check"
    remove_check_constraint :statement_imports, name: "statement_imports_reconciliation_status_check"
    remove_check_constraint :statement_imports, name: "statement_imports_status_check"
    remove_check_constraint :statement_imports, name: "statement_imports_kind_check"
    remove_check_constraint :categories, name: "categories_parent_not_self_check"
    remove_check_constraint :categories, name: "categories_kind_check"
    remove_check_constraint :accounts, name: "accounts_kind_check"

    remove_index :transactions, :categorization_status
    remove_index :transactions, %i[statement_month direction]
    remove_index :transactions, name: "index_transactions_for_category_matching"
    remove_index :transactions, name: "index_transactions_on_import_and_source_key"
    remove_index :categories, %i[parent_id name]
    remove_index :accounts, %i[name kind]

    add_column :transactions, :conciliated, :boolean, default: false, null: false
    remove_column :transactions, :source_key
    remove_column :transactions, :merchant_key
    remove_column :transactions, :categorization_status
    rename_column :transactions, :category_confidence, :confidence
    remove_index :statement_imports, name: "index_statement_imports_on_unique_source"
    remove_column :statement_imports, :error_message
    remove_column :statement_imports, :source_digest
  end

  private

  def deduplicate_accounts
    execute <<~SQL
      WITH duplicates AS (
        SELECT id, MIN(id) OVER (PARTITION BY name, kind) AS canonical_id
        FROM accounts
      )
      UPDATE transactions
      SET account_id = duplicates.canonical_id
      FROM duplicates
      WHERE transactions.account_id = duplicates.id AND duplicates.id <> duplicates.canonical_id;

      WITH duplicates AS (
        SELECT id, MIN(id) OVER (PARTITION BY name, kind) AS canonical_id
        FROM accounts
      )
      UPDATE statement_imports
      SET account_id = duplicates.canonical_id
      FROM duplicates
      WHERE statement_imports.account_id = duplicates.id AND duplicates.id <> duplicates.canonical_id;

      DELETE FROM accounts
      WHERE id NOT IN (SELECT MIN(id) FROM accounts GROUP BY name, kind);
    SQL
  end
end
