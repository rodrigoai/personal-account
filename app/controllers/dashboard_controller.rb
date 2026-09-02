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
    @trend_months = 11.downto(0).map { |offset| chart_month - offset.months }
    totals = Transaction.reportable.where(statement_month: first_month..chart_month.end_of_month)
      .group(:statement_month, :direction)
      .sum(:amount)
    @monthly_totals = @trend_months.map do |month|
      {
        label: month.strftime("%b"),
        income: totals.fetch([month.beginning_of_month, "income"], 0).to_f,
        outcome: totals.fetch([month.beginning_of_month, "outcome"], 0).to_f
      }
    end

    set_category_trends(first_month, chart_month)
  end

  private

  def set_category_trends(first_month, chart_month)
    @filter_categories = Category.order(:name).to_a
    requested_ids = Array.wrap(params[:category_ids]).filter_map do |value|
      value.to_i if value.is_a?(String) && value.match?(/\A[1-9]\d*\z/)
    end
    @selected_category_ids = @filter_categories.map(&:id) & requested_ids
    selected_categories = @filter_categories.index_by(&:id).values_at(*@selected_category_ids).compact
    category_ids_by_selection = selected_categories.to_h do |category|
      [category.id, [category.id, *category.descendant_ids]]
    end
    relevant_category_ids = category_ids_by_selection.values.flatten.uniq
    totals = Transaction.reportable
      .where(statement_month: first_month..chart_month.end_of_month, category_id: relevant_category_ids)
      .group(:statement_month, :category_id)
      .sum(:amount)

    @category_trends = selected_categories.map do |category|
      matching_ids = category_ids_by_selection.fetch(category.id)
      {
        category: category,
        values: @trend_months.map do |month|
          matching_ids.sum { |category_id| totals.fetch([month.beginning_of_month, category_id], 0).to_f }
        end
      }
    end
  end
end
