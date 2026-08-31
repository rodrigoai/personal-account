class ReportsController < ApplicationController
  def index
    @month = parsed_current_month
    @transactions = filter_by_month(Transaction.all).includes(:category)
    report = CategoryReport.new(@transactions)
    @report = report.call
    @totals = report.totals
  end
end
