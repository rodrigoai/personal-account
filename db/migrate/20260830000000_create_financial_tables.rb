class CreateFinancialTables < ActiveRecord::Migration[7.2]
  def change
    create_table :accounts do |t|
      t.string :name, null: false
      t.string :kind, null: false
      t.string :institution
      t.string :last_four
      t.timestamps
    end

    create_table :categories do |t|
      t.string :name, null: false
      t.string :kind, null: false, default: "both"
      t.references :parent, foreign_key: { to_table: :categories }
      t.string :color, default: "#9FE1C0"
      t.timestamps
    end

    create_table :statement_imports do |t|
      t.string :kind, null: false
      t.string :status, null: false, default: "pending"
      t.date :statement_month, null: false
      t.string :account_name
      t.references :account, foreign_key: true
      t.decimal :statement_total, precision: 12, scale: 2
      t.timestamps
    end

    create_table :transactions do |t|
      t.date :date, null: false
      t.date :statement_month, null: false
      t.string :description, null: false
      t.decimal :amount, precision: 12, scale: 2, null: false
      t.string :direction, null: false
      t.string :currency, default: "BRL"
      t.string :notes
      t.boolean :conciliated, null: false, default: false
      t.decimal :confidence, precision: 5, scale: 4
      t.references :account, foreign_key: true
      t.references :statement_import, foreign_key: true
      t.references :category, foreign_key: true
      t.timestamps
    end
    add_index :transactions, :statement_month
  end
end
