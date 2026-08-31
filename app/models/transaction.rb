class Transaction < ApplicationRecord
  belongs_to :account, optional: true
  belongs_to :statement_import, optional: true
  belongs_to :category, optional: true

  enum :direction, { income: "income", outcome: "outcome" }, scopes: false
  enum :categorization_status, { pending: "pending", categorized: "categorized" }, prefix: :categorization

  before_validation :assign_merchant_key
  before_validation :assign_source_key
  scope :for_month, ->(month) { where(statement_month: month.beginning_of_month..month.end_of_month) }
  scope :income, -> { where(direction: "income") }
  scope :outcome, -> { where(direction: "outcome") }
  scope :uncategorized, -> { where(category_id: nil) }
  scope :pending_categorization, -> { where(categorization_status: "pending") }
  scope :categorized, -> { where(categorization_status: "categorized") }

  def self.in_categories(category_ids)
    return all if category_ids.blank?

    matching_ids = Category.where(id: category_ids).flat_map { |category| [category.id, *category.descendant_ids] }
    where(category_id: matching_ids.uniq)
  end

  validates :description, :date, :statement_month, :amount, :direction, :categorization_status, presence: true
  validates :amount, numericality: { greater_than: 0 }
  validates :category_confidence, numericality: { in: 0..1 }, allow_nil: true
  validates :category, presence: true, if: :categorization_categorized?
  validate :category_kind_matches_direction

  def self.search(query)
    return all if query.blank?

    pattern = "%#{sanitize_sql_like(query.downcase)}%"
    left_joins(:account, :category).where(
      "LOWER(transactions.description) LIKE :query OR LOWER(transactions.notes) LIKE :query OR LOWER(accounts.name) LIKE :query OR LOWER(categories.name) LIKE :query",
      query: pattern
    )
  end

  def update_categorization(attributes)
    with_lock do
      saved = update(attributes.merge(categorization_status: :categorized, category_confidence: 1))

      if saved && saved_change_to_category_id?
        self.class.where(
          description: description,
          direction: direction,
          statement_month: statement_month.beginning_of_year..statement_month.end_of_year
        ).where.not(id: id).update_all(
          category_id: category_id,
          categorization_status: "categorized",
          category_confidence: 1,
          updated_at: Time.current
        )
      end

      saved
    end
  end

  private

  def assign_merchant_key
    self.merchant_key = CategoryMatcher.merchant_key(description)
  end

  def assign_source_key
    self.source_key ||= SecureRandom.uuid
  end

  def category_kind_matches_direction
    return unless category && !category.both? && category.kind != direction

    errors.add(:category, "must match the transaction direction")
  end
end
