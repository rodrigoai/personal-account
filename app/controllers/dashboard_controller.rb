class DashboardController < ApplicationController
  def show
    @month = parsed_current_month
    @transactions = filter_by_month(Transaction.reportable)
    @income = @transactions.income.sum(:amount)
    @outcome = @transactions.outcome.sum(:amount)
    @pending = @transactions.pending_categorization.includes(:account).order(date: :desc)
    @category_totals = @transactions.outcome.includes(category: :parent).to_a.group_by { |transaction| transaction.category&.root }.sort_by { |_category, rows| -rows.sum(&:amount) }

    chart_month = @month || Date.current.beginning_of_month
    first_month = chart_month - 11.months
    totals = Transaction.reportable.where(statement_month: first_month..chart_month.end_of_month)
      .group(:statement_month, :direction)
      .sum(:amount)
    @monthly_totals = 11.downto(0).map do |offset|
      month = chart_month - offset.months
      {
        label: month.strftime("%b"),
        income: totals.fetch([month.beginning_of_month, "income"], 0).to_f,
        outcome: totals.fetch([month.beginning_of_month, "outcome"], 0).to_f
      }
    end
  end
end
