class AddInstallmentToTransactions < ActiveRecord::Migration[7.2]
  def change
    add_column :transactions, :installment, :string
  end
end
