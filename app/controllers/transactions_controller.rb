class TransactionsController < ApplicationController
  def index
    session[:transaction_search] = params[:q].to_s.strip.first(200) if params[:q].is_a?(String)
    @query = session[:transaction_search].to_s
    set_category_filter
    @transactions = filter_by_month(Transaction.all).search(@query).in_categories(@selected_category_ids).includes(:account, :category).order(date: :desc, id: :desc)
    @transactions = @transactions.pending_categorization if params[:status] == "review"
  end

  def edit
    @transaction = Transaction.find(params[:id])
    set_categories
  end

  def update
    @transaction = Transaction.find(params[:id])
    if @transaction.update_categorization(transaction_params)
      redirect_to transactions_path, notice: "Entry saved. Category changes also apply to identical descriptions with the same direction in the same statement year."
    else
      set_categories
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_category_filter
    @filter_categories = Category.order(:name).to_a
    selection = params.key?(:category_ids) ? params[:category_ids] : session[:transaction_category_ids]
    requested_ids = Array.wrap(selection).filter_map do |value|
      value.to_i if value.is_a?(String) && value.match?(/\A[1-9]\d*\z/)
    end
    @selected_category_ids = @filter_categories.map(&:id) & requested_ids
    session[:transaction_category_ids] = @selected_category_ids.map(&:to_s)
  end

  def transaction_params
    params.require(:transaction).permit(:category_id, :notes)
  end

  def set_categories
    @categories = Category.where(kind: [@transaction.direction, "both"]).order(:name)
  end
end
