require "set"

class Category < ApplicationRecord
  NOT_IDENTIFIED_NAME = "Not identified"

  belongs_to :parent, class_name: "Category", optional: true
  has_many :children, class_name: "Category", foreign_key: :parent_id, inverse_of: :parent, dependent: :restrict_with_error
  has_many :transactions, dependent: :restrict_with_error
  enum :kind, { income: "income", outcome: "outcome", both: "both" }
  scope :roots, -> { where(parent_id: nil).order(:name) }
  validates :name, presence: true, uniqueness: { scope: :parent_id }
  validate :parent_must_not_create_cycle

  def self.not_identified!
    category = find_or_initialize_by(name: NOT_IDENTIFIED_NAME, parent_id: nil)
    category.kind = :both
    category.color = "#D8D6CF"
    category.save!
    category
  end

  def descendant_ids
    children.flat_map { |child| [child.id, *child.descendant_ids] }
  end

  def root
    parent ? parent.root : self
  end

  private

  def parent_must_not_create_cycle
    ancestor = parent
    visited = Set.new

    while ancestor
      if ancestor == self || visited.include?(ancestor.id)
        errors.add(:parent, "cannot create a category cycle")
        break
      end

      visited << ancestor.id
      ancestor = ancestor.parent
    end
  end
end
