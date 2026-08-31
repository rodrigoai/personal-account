class AddReconciliationFieldsToStatementImports < ActiveRecord::Migration[7.2]
  def change
    add_column :statement_imports, :normalized_total, :decimal, precision: 12, scale: 2
    add_column :statement_imports, :reconciliation_difference, :decimal, precision: 12, scale: 2
    add_column :statement_imports, :reconciliation_status, :string
  end
end
