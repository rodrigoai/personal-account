require "bigdecimal"
require "open3"
require "timeout"

module StatementParsers
  class Base
    MONEY_PATTERN = /-?\d{1,3}(?:\.\d{3})*,\d{2}/

    def initialize(statement_import)
      @statement_import = statement_import
    end

    def statement_total
      nil
    end

    private

    attr_reader :statement_import

    def parse_brazilian_money(value)
      text = value.to_s.strip
      return if text.blank?

      BigDecimal(text.gsub(".", "").tr(",", "."))
    rescue ArgumentError
      nil
    end

    def capture_command(*command)
      stdin = stdout = stderr = wait_thread = nil
      stdout_reader = stderr_reader = nil
      stdin, stdout, stderr, wait_thread = Open3.popen3(*command)
      stdin.close
      stdout_reader = Thread.new { stdout.read }
      stderr_reader = Thread.new { stderr.read }
      timeout = ENV.fetch("DOCUMENT_PARSE_TIMEOUT", 60).to_i.clamp(1, 300)
      status = Timeout.timeout(timeout) { wait_thread.value }
      [stdout_reader.value, stderr_reader.value, status]
    rescue Timeout::Error
      terminate_process(wait_thread)
      raise StatementParser::ParseError, "Document parsing exceeded the time limit"
    ensure
      [stdin, stdout, stderr].compact.each { |stream| stream.close unless stream.closed? }
      [stdout_reader, stderr_reader].compact.each { |reader| reader.kill if reader.alive? }
    end

    def terminate_process(wait_thread)
      return unless wait_thread&.alive?

      Process.kill("TERM", wait_thread.pid)
      return if wait_thread.join(1)

      Process.kill("KILL", wait_thread.pid)
      wait_thread.join
    rescue Errno::ESRCH, Errno::ECHILD
      nil
    end
  end
end
