require "test_helper"

class StatementParserTest < ActiveSupport::TestCase
  FakeFilename = Struct.new(:extension)
  FakeFile = Struct.new(:content, :extension) do
    def filename
      FakeFilename.new(extension)
    end

    def download
      content
    end
  end
  FakeImport = Struct.new(:kind, :file, :statement_month)

  test "parses a sanitized Santander CSV without treating its contents as a path" do
    content = file_fixture("santander_bank.csv").binread
    import = FakeImport.new("bank", FakeFile.new(content, "csv"), Date.new(2026, 8, 1))

    rows = StatementParser.new(import).call

    assert_equal 3, rows.size
    assert_equal BigDecimal("1500.00"), rows.first["amount"]
    assert_equal "income", rows.first["direction"]
    assert_equal BigDecimal("150.50"), rows.select { |row| row["direction"] == "outcome" }.sum { |row| row["amount"] }
    assert rows.all? { |row| row["amount"].is_a?(BigDecimal) }
  end

  test "parses Santander card columns without confusing installment dates" do
    text = <<~TEXT
      Olá! Esta é a fatura do seu cartão SANTANDER
      Total a Pagar R$ 199,99
      Detalhamento da Fatura
      Despesas
        3  28/07 TEST MARKET                  02/03       99,99              29/07 TEST PHARMACY       100,00
      Resumo da Fatura
      (=) Saldo Desta Fatura 199,99
    TEXT
    import = FakeImport.new("credit_card", FakeFile.new("unused", "pdf"), Date.new(2026, 8, 1))
    adapter = StatementParsers::SantanderCreditCardPdf.new(import)

    adapter.stub(:extract_pdf_text, text) do
      rows = adapter.call

      assert_equal 2, rows.size
      assert_equal ["TEST MARKET", "TEST PHARMACY"], rows.map { |row| row["description"] }
      assert_equal [BigDecimal("99.99"), BigDecimal("100.00")], rows.map { |row| row["amount"] }
      assert_equal ["02/03", nil], rows.map { |row| row["installment"] }
      assert_equal BigDecimal("199.99"), adapter.statement_total
    end
  end

  test "uses the Ruby PDF fallback when pdftotext is unavailable" do
    text = <<~TEXT
      Olá! Esta é a fatura do seu cartãoSANTANDER
      TotalaPagar R$ 10,00
      DetalhamentodaFatura
      Despesas
      01/07 TEST MARKET 10,00
      SaldoDestaFatura 10,00
    TEXT
    import = FakeImport.new("credit_card", FakeFile.new("fake pdf bytes", "pdf"), Date.new(2026, 7, 1))
    adapter = StatementParsers::SantanderCreditCardPdf.new(import)
    page = Struct.new(:text).new(text)
    reader = Struct.new(:pages).new([page])
    previous_executable = ENV["PDFTOTEXT_BIN"]
    ENV["PDFTOTEXT_BIN"] = "/definitely/missing/pdftotext"

    PDF::Reader.stub(:new, ->(*) { reader }) do
      rows = adapter.call

      assert_equal 1, rows.size
      assert_equal "TEST MARKET", rows.first["description"]
      assert_equal BigDecimal("10.00"), adapter.statement_total
    end
  ensure
    ENV["PDFTOTEXT_BIN"] = previous_executable
  end

  test "rejects a bank PDF instead of guessing a parser" do
    import = FakeImport.new("bank", FakeFile.new("unused", "pdf"), Date.new(2026, 8, 1))

    assert_raises(StatementParser::UnsupportedFormat) { StatementParser.new(import).call }
  end
end
