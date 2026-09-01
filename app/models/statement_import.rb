class StatementImport < ApplicationRecord
  MAX_FILE_SIZE = 10.megabytes
  ALLOWED_EXTENSIONS = %w[pdf csv xls xlsx].freeze
  ALLOWED_CONTENT_TYPES = %w[
    application/pdf
    text/csv
    text/plain
    application/vnd.ms-excel
    application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
  ].freeze

  belongs_to :account, optional: true
  belongs_to :bank_payment_transaction,
    class_name: "Transaction",
    optional: true,
    inverse_of: :paid_credit_card_statement
  has_many :transactions, dependent: :destroy
  has_one_attached :file
  enum :kind, { credit_card: "credit_card", bank: "bank" }
  enum :status, { pending: "pending", processing: "processing", needs_review: "needs_review", completed: "completed", failed: "failed" }

  before_validation :normalize_statement_month
  before_validation :assign_source_digest, if: -> { file.attached? }
  validates :file, presence: true
  validates :statement_month, presence: true
  validates :kind, presence: true
  validates :source_digest, uniqueness: { scope: %i[kind statement_month], message: "has already been imported for this month" }, allow_nil: true
  validate :supported_file_type
  validate :file_size_within_limit
  validate :valid_bank_payment

  def payment_candidates
    return Transaction.none unless credit_card? && statement_total.present?

    used_payment_ids = StatementImport.where.not(id: id).where.not(bank_payment_transaction_id: nil).select(:bank_payment_transaction_id)
    Transaction.transaction_kind_bank.outcome
      .where(statement_month: statement_month, amount: statement_total)
      .where.not(id: used_payment_ids)
      .order(date: :asc, id: :asc)
  end

  private

  def supported_file_type
    return unless file.attached?

    extension = file.filename.extension.to_s.downcase
    unless ALLOWED_EXTENSIONS.include?(extension) && ALLOWED_CONTENT_TYPES.include?(file.blob.content_type)
      errors.add(:file, "must be a PDF, CSV, XLS, or XLSX file")
    end
  end

  def file_size_within_limit
    return unless file.attached? && file.blob.byte_size > MAX_FILE_SIZE

    errors.add(:file, "must be smaller than 10 MB")
  end

  def normalize_statement_month
    self.statement_month = statement_month.beginning_of_month if statement_month
  end

  def valid_bank_payment
    return unless bank_payment_transaction

    errors.add(:bank_payment_transaction, "can only be linked to a credit-card statement") unless credit_card?
    errors.add(:bank_payment_transaction, "must be a bank expense") unless bank_payment_transaction.transaction_kind_bank? && bank_payment_transaction.outcome?
    if statement_total.present? && bank_payment_transaction.amount != statement_total
      errors.add(:bank_payment_transaction, "must have the same amount as the statement total")
    end
  end

  def assign_source_digest
    self.source_digest = file.blob.checksum
  end
end
