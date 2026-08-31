class CategoryMatcher
  Match = Data.define(:category, :confidence)

  def self.merchant_key(description)
    I18n.transliterate(description.to_s)
      .upcase
      .gsub(/\b\d{6,}\b/, " ")
      .gsub(/[^A-Z0-9]+/, " ")
      .squish
  end

  def initialize(description:, direction:, account:)
    @merchant_key = self.class.merchant_key(description)
    @direction = direction
    @account = account
  end

  def call
    return Match.new(category: nil, confidence: nil) if @merchant_key.blank?

    previous = Transaction.categorized
      .where(merchant_key: @merchant_key, direction: @direction, account: @account)
      .where.not(category_id: nil)
      .order(updated_at: :desc)
      .first

    Match.new(category: previous&.category, confidence: previous ? BigDecimal("1.0") : nil)
  end
end
