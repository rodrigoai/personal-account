require "json"
require "net/http"
require "uri"

class OpenaiTransactionClassifier
  API_URI = URI("https://api.openai.com/v1/responses")
  DEFAULT_MODEL = "gpt-5.4-nano"
  DEFAULT_CONFIDENCE_THRESHOLD = BigDecimal("0.65")

  Result = Data.define(:category, :confidence)
  ConfigurationError = Class.new(StandardError)
  ResponseError = Class.new(StandardError)

  def initialize(rows:, categories:, api_key: ENV["OPENAI_API_KEY"], model: ENV.fetch("OPENAI_TRANSACTION_MODEL", DEFAULT_MODEL))
    @rows = rows
    @categories = categories.index_by(&:id)
    @api_key = api_key
    @model = model
  end

  def call
    return {} if @rows.empty?
    raise ConfigurationError, "OPENAI_API_KEY is required to classify imported transactions" if @api_key.blank?
    raise ConfigurationError, "Create at least one category before importing transactions" if @categories.empty?

    payload = {
      model: @model,
      store: false,
      reasoning: { effort: "none" },
      instructions: <<~INSTRUCTIONS.squish,
        Classify each Brazilian bank transaction into one of the supplied categories.
        Use only a supplied category id whose kind matches the transaction direction (or has kind both).
        If the description does not provide enough evidence for a reliable classification, return a null category_id.
      INSTRUCTIONS
      input: JSON.generate(
        transactions: @rows.map { |row| serialized_row(row) },
        categories: @categories.values.map { |category| { id: category.id, name: category.name, kind: category.kind } }
      ),
      text: {
        format: {
          type: "json_schema",
          name: "transaction_classifications",
          strict: true,
          schema: response_schema
        }
      }
    }

    parse_response(perform_request(payload))
  end

  private

  def serialized_row(row)
    {
      transaction_index: row.fetch(:transaction_index),
      date: row.fetch(:date).to_s,
      description: row.fetch(:description),
      amount: row.fetch(:amount).to_s,
      direction: row.fetch(:direction)
    }
  end

  def response_schema
    {
      type: "object",
      properties: {
        classifications: {
          type: "array",
          items: {
            type: "object",
            properties: {
              transaction_index: { type: "integer" },
              category_id: { type: ["integer", "null"] },
              confidence: { type: "number", minimum: 0, maximum: 1 }
            },
            required: %w[transaction_index category_id confidence],
            additionalProperties: false
          }
        }
      },
      required: ["classifications"],
      additionalProperties: false
    }
  end

  def perform_request(payload)
    request = Net::HTTP::Post.new(API_URI)
    request["Authorization"] = "Bearer #{@api_key}"
    request["Content-Type"] = "application/json"
    request.body = JSON.generate(payload)

    Net::HTTP.start(API_URI.host, API_URI.port, use_ssl: true, open_timeout: 10, read_timeout: 60) do |http|
      response = http.request(request)
      unless response.is_a?(Net::HTTPSuccess)
        message = JSON.parse(response.body).dig("error", "message") rescue response.body
        raise ResponseError, "OpenAI classification failed (#{response.code}): #{message.to_s.truncate(500)}"
      end

      response.body
    end
  end

  def parse_response(response_body)
    response = JSON.parse(response_body)
    output_text = response["output_text"] || response.fetch("output", []).filter_map do |item|
      next unless item["type"] == "message"

      item.fetch("content", []).find { |content| content["type"] == "output_text" }&.fetch("text", nil)
    end.first
    raise ResponseError, "OpenAI classification returned no structured output" if output_text.blank?

    parsed = JSON.parse(output_text)
    valid_indexes = @rows.index_by { |row| row.fetch(:transaction_index) }

    parsed.fetch("classifications").each_with_object({}) do |classification, results|
      index = classification.fetch("transaction_index")
      row = valid_indexes[index]
      next unless row

      category = @categories[classification["category_id"]]
      confidence = BigDecimal(classification.fetch("confidence").to_s)
      category = nil unless compatible?(category, row.fetch(:direction)) && confidence >= confidence_threshold
      results[index] = Result.new(category: category, confidence: category ? confidence : BigDecimal("0"))
    end
  rescue JSON::ParserError, KeyError => e
    raise ResponseError, "OpenAI classification returned invalid structured output: #{e.message}"
  end

  def compatible?(category, direction)
    category && (category.both? || category.kind == direction)
  end

  def confidence_threshold
    BigDecimal(ENV.fetch("OPENAI_CATEGORY_CONFIDENCE", DEFAULT_CONFIDENCE_THRESHOLD.to_s).to_s)
  end
end
