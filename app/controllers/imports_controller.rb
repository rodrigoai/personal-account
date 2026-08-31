class ImportsController < ApplicationController
  def index
    @imports = filter_by_month(StatementImport.all).order(created_at: :desc)
  end

  def new
    @import = StatementImport.new
  end

  def create
    @import = StatementImport.new(import_params)
    if @import.save
      redirect_to import_path(@import), notice: "Statement uploaded. Start the review when you’re ready."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @import = StatementImport.find(params[:id])
    @transactions = @import.transactions.includes(:category).order(date: :asc)
  end

  def process_file
    @import = StatementImport.find(params[:id])
    if @import.pending? || @import.failed?
      StatementIngestionJob.perform_later(@import.id)
      redirect_to import_path(@import), notice: "We’re reading the Santander statement and normalizing its entries."
    else
      redirect_to import_path(@import), alert: "This statement is already processing or has been processed."
    end
  end

  def destroy
    @import = StatementImport.find(params[:id])

    StatementImport.transaction do
      @import.lock!
      if @import.processing?
        return redirect_to import_path(@import), alert: "This import cannot be deleted while it is processing."
      end

      filename = @import.file.filename.to_s
      @import.destroy!
      redirect_to imports_path, notice: "#{filename} and its imported transactions were deleted. You can upload it again."
    end
  end

  def month
    statement_month = parsed_statement_month
    imports = StatementImport.where(statement_month: statement_month)

    StatementImport.transaction do
      locked_imports = imports.lock.to_a
      if locked_imports.any?(&:processing?)
        return redirect_to imports_path, alert: "#{statement_month.strftime('%B %Y')} cannot be cleared while an import is processing."
      end

      import_count = locked_imports.size
      transaction_count = Transaction.for_month(statement_month).count

      locked_imports.each(&:destroy!)
      Transaction.for_month(statement_month).destroy_all

      redirect_to imports_path, notice: "Cleared #{statement_month.strftime('%B %Y')}: #{import_count} #{'import'.pluralize(import_count)} and #{transaction_count} #{'transaction'.pluralize(transaction_count)} deleted."
    end
  rescue Date::Error, TypeError
    redirect_to imports_path, alert: "Choose a valid month to clear."
  end

  private

  def parsed_statement_month
    Date.strptime(params.require(:month), "%Y-%m").beginning_of_month
  end

  def import_params
    attributes = params.require(:statement_import).permit(:file, :kind, :account_name, :statement_month)
    if attributes[:statement_month].present? && attributes[:statement_month].match?(/\A\d{4}-\d{2}\z/)
      attributes[:statement_month] = Date.strptime(attributes[:statement_month], "%Y-%m")
    end
    attributes
  rescue Date::Error
    attributes[:statement_month] = nil
    attributes
  end
end
