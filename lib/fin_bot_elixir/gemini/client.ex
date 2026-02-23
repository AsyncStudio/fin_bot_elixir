defmodule FinBotElixir.Gemini.Client do
  @model "gemini-1.5-flash"

  require Logger

  alias FinBotElixir.Financial.Transaction

  @doc """
  Classifies the user message and, in a single AI call, extracts all data needed
  to handle the response. Returns `{:ok, context}` where context is a map with:
    - `:message_type` — one of `:transaction`, `:data_query`, `:finance_tip`, `:unrelated`
    - `:transaction_data` — map with transaction fields, or `nil`
    - `:ai_response` — AI-generated reply text (for transactions and finance tips), or `nil`
    - `:original_text` — the raw user input
  """
  def classify_message(text) do
    prompt = build_classification_prompt(text)

    {:ok, response} =
      Gemini.generate(prompt,
        response_json_schema: %{
          "type" => "object",
          "required" => ["message_type"],
          "properties" => %{
            "message_type" => %{"type" => "string"},
            "transaction_data" => %{
              "type" => "object",
              "properties" => %{
                "amount" => %{"type" => "number"},
                "description" => %{"type" => "string"},
                "category" => %{"type" => "string"},
                "type" => %{"type" => "string"}
              }
            },
            "ai_response" => %{"type" => "string"}
          }
        },
        response_mime_type: "application/json",
        temperature: 0.3
      )

    with {:ok, data} <- parse_response(response) do
      message_type = parse_message_type(data["message_type"])

      context = %{
        message_type: message_type,
        transaction_data: data["transaction_data"],
        ai_response: data["ai_response"],
        original_text: text
      }

      Logger.info("Mensagem classificada como '#{message_type}': #{text}")
      {:ok, context}
    end
  end

  def process_financial_tip_request(context) do
    prompt = build_financial_tip_prompt(context.original_text)
    {:ok, response} = Gemini.generate(prompt)

    context |> Map.put(:ai_response, parse_text_response(response) )
  end

  defp parse_message_type("transaction"), do: :transaction
  defp parse_message_type("data_query"), do: :data_query
  defp parse_message_type("finance_tip"), do: :finance_tip
  defp parse_message_type(_), do: :unrelated

  defp build_classification_prompt(text) do
    categories = Transaction.category_values() |> Enum.join("|")

    """
    Analyze the following message and classify it into exactly one of these types:
    - "transaction": a financial transaction to be recorded (expense or income with a clear amount)
    - "data_query": a question about the user's recorded financial data or spending history
    - "finance_tip": a question or request about personal finance tips, strategies, or habits
    - "unrelated": anything not related to personal finance

    Message: "#{text}"

    Return a JSON object with:
    {
      "message_type": "transaction|data_query|finance_tip|unrelated",
      "transaction_data": {
        "amount": positive number,
        "description": short descriptive name (e.g. "Uber", "Salary"),
        "category": one of [#{categories}],
        "type": "expense|income"
      },
      "ai_response": helpful reply text for the user
    }

    Rules:
    - For "transaction": fill transaction_data and set ai_response to a short friendly confirmation in the same language as the user's message. Category defaults to "other" if unsure; type defaults to "expense" if unsure.
    - For "finance_tip": set transaction_data to null and set ai_response to a helpful, practical finance tip or answer in the same language as the user's message.
    - For "data_query" and "unrelated": set transaction_data to null and ai_response to null.

    Return ONLY valid JSON.
    """
  end

  defp build_financial_tip_prompt(query) do
    """
    Provide a helpful, practical personal finance tip or answer to the following question/request:
    "#{query}"

    Return the response as plain text in the same language as the query.
    """
  end

  def parse_text_response(body) do
    text_response =
      body.candidates
      |> List.first()
      |> get_in([Access.key!(:content), Access.key!(:parts)])
      |> List.first()

    text_response.text
  end

  defp parse_response(body) do
    text_response =
      body.candidates
      |> List.first()
      |> get_in([Access.key!(:content), Access.key!(:parts)])
      |> List.first()

    case Jason.decode(text_response.text) do
      {:ok, data} -> {:ok, data}
      _ -> {:error, "Falha no parse do JSON da IA"}
    end
  end
end
