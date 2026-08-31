class Account < ApplicationRecord
  has_many :transactions, dependent: :restrict_with_error
  has_many :statement_imports, dependent: :restrict_with_error
  enum :kind, { bank: "bank", credit_card: "credit_card" }

  validates :name, presence: true, uniqueness: { scope: :kind }
  validates :kind, presence: true
end
