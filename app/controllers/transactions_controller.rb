class TransactionsController < ApplicationController
  SORT_COLUMNS = { "date" => :date, "name" => :description, "value" => :amount }.freeze
  SORT_DIRECTIONS = %w[asc desc].freeze

  def index
    session[search_session_key] = params[:q].to_s.strip.first(200) if params[:q].is_a?(String)
    @query = session[search_session_key].to_s
    set_category_filter
    set_sorting
    @transactions = filter_by_month(transaction_scope).search(@query).in_categories(@selected_category_ids).includes(:account, :category, :paid_credit_card_statement)
    @transactions = @transactions.pending_categorization if params[:status] == "review"
    @transactions = sorted_transactions(@transactions)
    @index_path = transaction_index_path
    @page_title = transaction_page_title
    @page_description = transaction_page_description
    render "transactions/index"
  end

  def edit
    @transaction = Transaction.find(params[:id])
    @back_path = index_path_for(@transaction)
    set_categories
  end

  def update
    @transaction = Transaction.find(params[:id])
    if @transaction.update_categorization(transaction_params)
      redirect_to index_path_for(@transaction), notice: "Entry saved. Category changes also apply to identical descriptions with the same direction in the same statement year."
    else
      @back_path = index_path_for(@transaction)
      set_categories
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_sorting
    @sort = SORT_COLUMNS.key?(params[:sort]) ? params[:sort] : "date"
    @direction = SORT_DIRECTIONS.include?(params[:direction]) ? params[:direction] : "desc"
  end

  def sorted_transactions(scope)
    direction = @direction.to_sym
    return scope.order(Arel.sql("LOWER(transactions.description) #{@direction.upcase}"), id: direction) if @sort == "name"

    scope.order(SORT_COLUMNS.fetch(@sort) => direction, id: direction)
  end

  def set_category_filter
    @filter_categories = Category.order(:name).to_a
    selection = params.key?(:category_ids) ? params[:category_ids] : session[category_session_key]
    requested_ids = Array.wrap(selection).filter_map do |value|
      value.to_i if value.is_a?(String) && value.match?(/\A[1-9]\d*\z/)
    end
    @selected_category_ids = @filter_categories.map(&:id) & requested_ids
    session[category_session_key] = @selected_category_ids.map(&:to_s)
  end

  def transaction_params
    params.require(:transaction).permit(:category_id, :notes)
  end

  def set_categories
    @categories = Category.where(kind: [@transaction.direction, "both"]).order(:name)
  end

  def transaction_scope
    Transaction.transaction_kind_bank
  end

  def search_session_key
    :transaction_search
  end

  def category_session_key
    :transaction_category_ids
  end

  def index_path_for(transaction)
    transaction.transaction_kind_credit_card? ? credit_card_transactions_path : transactions_path
  end

  def transaction_index_path
    transactions_path
  end

  def transaction_page_title
    "Transactions"
  end

  def transaction_page_description
    "Current-account movements, with linked credit-card payments clearly identified."
  end
end
