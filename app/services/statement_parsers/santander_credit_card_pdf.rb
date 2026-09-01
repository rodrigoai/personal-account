require "open3"
require "pdf-reader"
require "stringio"
require "tmpdir"

module StatementParsers
  class SantanderCreditCardPdf < Base
    DATE_PATTERN = /\d{2}\/\d{2}(?!\/)/
    INSTALLMENT_PATTERN = /(?<current>\d{1,2})\/(?<total>\d{1,2})/
    DETAIL_HEADING_PATTERN = /Detalhamento\s*da\s*Fatura/i
    SANTANDER_CARD_PATTERN = /cartão\s*SANTANDER/i
    EXCLUDED_DESCRIPTIONS = /\b(?:Compra|Data|Descrição|Parcela|R\$|US\$|VALOR TOTAL)\b/i
    PAYMENT_DESCRIPTION = /DEB.*FATURA|PAGAMENTO.*FATURA/i

    def call
      validate_layout!
      source_index = 0

      detail_pages.flat_map do |page|
        page.lines.flat_map do |line|
          parse_line(line).map do |row|
            row["source_index"] = source_index
            source_index += 1
            row
          end
        end
      end
    end

    def statement_total
      @statement_total ||= begin
        value = pdf_text[/Saldo\s*Desta\s*Fatura\s*(#{MONEY_PATTERN})/i, 1] ||
          pdf_text[/Total\s*a\s*Pagar\s*R\$\s*(#{MONEY_PATTERN})/i, 1]
        parse_brazilian_money(value)
      end
    end

    private

    def detail_pages
      @detail_pages ||= pdf_text.split("\f").select { |page| page.match?(DETAIL_HEADING_PATTERN) }
    end

    def validate_layout!
      return if pdf_text.match?(SANTANDER_CARD_PATTERN) && detail_pages.any?

      raise StatementParser::ParseError, "The PDF is not a recognized Santander credit-card statement"
    end

    # Santander PDFs render independent card columns on the same physical line.
    # Pairing each money token with the first date since the previous token avoids
    # mistaking an installment such as 03/12 for a second transaction column.
    def parse_line(line)
      previous_money_end = 0

      line.to_enum(:scan, MONEY_PATTERN).filter_map do
        money_match = Regexp.last_match
        segment = line[previous_money_end...money_match.begin(0)]
        previous_money_end = money_match.end(0)
        date_match = segment.match(DATE_PATTERN)
        next unless date_match

        details = segment[date_match.end(0)..].to_s
        installment_match = details.match(/\s+#{INSTALLMENT_PATTERN}\s*\z/)
        description = details.sub(/\s+#{INSTALLMENT_PATTERN}\s*\z/, "").squish
        next if description.blank? || description.match?(EXCLUDED_DESCRIPTIONS)
        next if money_match[0].start_with?("-") && description.match?(PAYMENT_DESCRIPTION)

        amount = parse_brazilian_money(money_match[0])
        next if amount.nil? || amount.zero?

        {
          "date" => statement_date(date_match[0]),
          "description" => description,
          "amount" => amount.abs,
          "direction" => money_match[0].start_with?("-") ? "income" : "outcome",
          "currency" => "BRL",
          "installment" => normalized_installment(installment_match)
        }
      end
    end

    def normalized_installment(match)
      return unless match

      format("%02d/%02d", match[:current].to_i, match[:total].to_i)
    end

    def statement_date(date_text)
      day, month = date_text.split("/").map(&:to_i)
      reference = statement_import.statement_month.end_of_month
      [reference.year - 1, reference.year, reference.year + 1]
        .filter_map { |year| Date.new(year, month, day) rescue nil }
        .min_by { |date| (date - reference).abs }
    end

    def pdf_text
      @pdf_text ||= extract_pdf_text
    end

    def extract_pdf_text
      pdf_data = statement_import.file.download
      executable = pdftotext_executable

      return extract_with_poppler(pdf_data, executable) if executable

      extract_with_pdf_reader(pdf_data)
    end

    def extract_with_poppler(pdf_data, executable)
      Dir.mktmpdir("ledgerly-santander-card") do |directory|
        input = File.join(directory, "statement.pdf")
        File.binwrite(input, pdf_data)
        stdout, stderr, status = capture_command(executable, "-layout", input, "-")
        raise StatementParser::ParseError, "Santander PDF extraction failed: #{stderr.to_s.strip.presence || status.inspect}" unless status.success?

        stdout
      end
    end

    def extract_with_pdf_reader(pdf_data)
      reader = PDF::Reader.new(StringIO.new(pdf_data))
      reader.pages.map(&:text).join("\f")
    rescue PDF::Reader::MalformedPDFError, PDF::Reader::UnsupportedFeatureError => error
      raise StatementParser::ParseError, "The credit-card PDF could not be read: #{error.message}"
    end

    def pdftotext_executable
      candidate = ENV.fetch("PDFTOTEXT_BIN", "pdftotext")
      return candidate if candidate.include?(File::SEPARATOR) && File.file?(candidate) && File.executable?(candidate)

      ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).each do |directory|
        path = File.join(directory, candidate)
        return path if File.file?(path) && File.executable?(path)
      end

      nil
    end
  end
end
