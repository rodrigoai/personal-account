module TransactionsHelper
  GOOGLE_SEARCH_LOCATION = "São josé dos campos".freeze

  def google_transaction_search_url(description)
    "https://www.google.com/search?#{ { q: [description, GOOGLE_SEARCH_LOCATION].join(" ") }.to_query }"
  end
end
