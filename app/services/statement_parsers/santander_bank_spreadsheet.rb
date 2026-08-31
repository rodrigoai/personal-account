require "csv"
require "open3"
require "tmpdir"

module StatementParsers
  class SantanderBankSpreadsheet < Base
    SANTANDER_SIGNATURE = "EXTRATO DE CONTA CORRENTE"

    def call
      rows = spreadsheet_rows
      validate_layout!(rows)
      header_index = rows.index { |row| normalized(row.first) == "data" }
      header = rows.fetch(header_index)
      indexes = column_indexes(header)

      rows.drop(header_index + 1).filter_map.with_index do |row, source_index|
        parse_row(row, indexes, source_index)
      end
    end

    private

    def extension
      @extension ||= statement_import.file.filename.extension.to_s.downcase
    end

    def spreadsheet_rows
      return parse_csv(statement_import.file.download) if extension == "csv"

      Dir.mktmpdir("ledgerly-santander-bank") do |directory|
        input = File.join(directory, "statement.#{extension}")
        output = File.join(directory, "statement.csv")
        File.binwrite(input, statement_import.file.download)
        executable = ENV.fetch("LIBREOFFICE_BIN", "soffice")
        _stdout, stderr, status = capture_command(executable, "--headless", "--convert-to", "csv", "--outdir", directory, input)
        unless status.success? && File.file?(output)
          raise StatementParser::ParseError, "Santander spreadsheet conversion failed: #{stderr.to_s.strip.presence || status.inspect}"
        end

        parse_csv(File.binread(output))
      end
    rescue Errno::ENOENT
      raise StatementParser::ParseError, "LibreOffice is required to read Santander .#{extension} statements"
    end

    def parse_csv(content)
      utf8 = content.dup.force_encoding(Encoding::UTF_8).sub(/\A\uFEFF/, "")
      CSV.parse(utf8, liberal_parsing: true)
    end

    def validate_layout!(rows)
      signature = rows.first(8).flatten.compact.join(" ").upcase
      return if signature.include?(SANTANDER_SIGNATURE)

      raise StatementParser::ParseError, "The spreadsheet is not a recognized Santander current-account statement"
    end

    def column_indexes(header)
      normalized_header = header.map { |value| normalized(value) }
      indexes = {
        date: normalized_header.index("data"),
        description: normalized_header.index { |value| value.start_with?("descricao") },
        credit: normalized_header.index { |value| value.start_with?("credito") },
        debit: normalized_header.index { |value| value.start_with?("debito") }
      }
      return indexes if indexes.values.all?

      raise StatementParser::ParseError, "The Santander statement is missing Data, Descrição, Crédito, or Débito columns"
    end

    def parse_row(row, indexes, source_index)
      date_text = row[indexes[:date]].to_s.strip
      return unless date_text.match?(/\A\d{2}\/\d{2}\/\d{4}\z/)

      credit = parse_brazilian_money(row[indexes[:credit]])
      debit = parse_brazilian_money(row[indexes[:debit]])
      return if credit.nil? && debit.nil?

      amount, direction = credit ? [credit.abs, "income"] : [debit.abs, "outcome"]
      {
        "source_index" => source_index,
        "date" => Date.strptime(date_text, "%d/%m/%Y"),
        "description" => row[indexes[:description]].to_s.squish,
        "amount" => amount,
        "direction" => direction,
        "currency" => "BRL"
      }
    end

    def normalized(value)
      I18n.transliterate(value.to_s).strip.downcase
    end
  end
end
