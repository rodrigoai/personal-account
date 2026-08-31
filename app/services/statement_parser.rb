class StatementParser
  class ParseError < StandardError; end
  class UnsupportedFormat < ParseError; end

  def initialize(statement_import)
    @statement_import = statement_import
  end

  def call
    adapter.call
  end

  def statement_total
    adapter.statement_total
  end

  private

  attr_reader :statement_import

  def adapter
    @adapter ||= begin
      extension = statement_import.file.filename.extension.to_s.downcase

      case [statement_import.kind.to_s, extension]
      in ["bank", "csv" | "xls" | "xlsx"]
        StatementParsers::SantanderBankSpreadsheet.new(statement_import)
      in ["credit_card", "pdf"]
        StatementParsers::SantanderCreditCardPdf.new(statement_import)
      else
        raise UnsupportedFormat, "Santander #{statement_import.kind.humanize.downcase} statements do not support .#{extension} files"
      end
    end
  end
end
