class CategoryReport
  def initialize(transactions)
    @transactions = transactions
  end

  def call
    categories = Category.all.index_by(&:id)
    totals = {}

    @transactions.each do |transaction|
      category = categories[transaction.category_id]
      loop do
        row = totals[category&.id] ||= { category: category, income: 0, outcome: 0, count: 0 }
        row[transaction.direction.to_sym] += transaction.amount
        row[:count] += 1
        break unless category&.parent_id

        category = categories.fetch(category.parent_id)
      end
    end

    children = totals.values.group_by { |row| row[:category]&.parent_id }
    flatten(children, nil)
  end

  def totals
    income = @transactions.select(&:income?).sum(&:amount)
    outcome = @transactions.select(&:outcome?).sum(&:amount)
    { income: income, outcome: outcome, balance: income - outcome }
  end

  private

  def flatten(children, parent_id, depth = 0)
    children.fetch(parent_id, []).sort_by { |row| [-row[:outcome], row[:category]&.name.to_s] }.flat_map do |row|
      row = row.merge(depth: depth, balance: row[:income] - row[:outcome])
      descendants = row[:category] ? flatten(children, row[:category].id, depth + 1) : []
      [row, *descendants]
    end
  end
end
