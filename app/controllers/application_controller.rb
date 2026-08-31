class ApplicationController < ActionController::Base
  before_action :remember_month_filter
  helper_method :current_month, :month_filter_label, :month_filter_path

  private

  def current_month
    session[:data_month] || Date.current.strftime("%Y-%m")
  end

  def parsed_current_month
    Date.strptime(current_month, "%Y-%m").beginning_of_month unless current_month == "all"
  end

  def month_filter_label
    parsed_current_month&.strftime("%B %Y") || "All months"
  end

  def month_filter_path
    url_for(controller: controller_path, action: controller_name == "dashboard" ? :show : :index, only_path: true)
  end

  def filter_by_month(scope)
    month = parsed_current_month
    month ? scope.where(statement_month: month..month.end_of_month) : scope
  end

  def remember_month_filter
    # Only navigation can change the filter; DELETE /imports/month uses its own month.
    return unless request.get? && params.key?(:month)

    value = params[:month]
    if value == "all" || value == ""
      session[:data_month] = "all"
    elsif value.is_a?(String) && value.match?(/\A\d{4}-\d{2}\z/)
      month = Date.strptime(value, "%Y-%m")
      session[:data_month] = value if month.year.positive?
    end
  rescue Date::Error
    # Ignore malformed links without losing the previously selected month.
  end
end
