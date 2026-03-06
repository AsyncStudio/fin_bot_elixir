defmodule FinBotElixir.Gemini.Client do
  @model "gemini-1.5-flash"

  @response_schema %{
    "type" => "object",
    "required" => ["message_type", "ai_response"],
    "properties" => %{
      "message_type" => %{"type" => "string"},
      "transaction_data" => %{
        "type" => "object",
        "properties" => %{
          "amount" => %{"type" => "number"},
          "description" => %{"type" => "string"},
          "category" => %{"type" => "string"},
          "type" => %{"type" => "string"},
          "tags" => %{
            "type" => "array",
            "items" => %{"type" => "string"}
          }
        }
      },
      "ai_response" => %{"type" => "string"}
    }
  }

  @response_mime_type "application/json"

  require Logger

  alias FinBotElixir.Financial.Transaction

  @doc """
  Classifies the user message and, in a single AI call, extracts all data needed
  to handle the response. Returns `{:ok, context}` where context is a map with:
    - `:message_type` — one of `:transaction`, `:data_query`, `:finance_tip`, `:unrelated`
    - `:transaction_data` — map with transaction fields (including `tags`), or `nil`
    - `:ai_response` — AI-generated reply text (for transactions and finance tips), or `nil`
    - `:original_text` — the raw user input

  Optionally accepts a list of existing tag names to guide the AI in reusing tags.
  """
  def classify_message(user_text, existing_tags \\ []) do
    prompt = build_classification_prompt(user_text, existing_tags)

    with {:ok, response} <-
           Gemini.generate(prompt,
             response_json_schema: @response_schema,
             response_mime_type: @response_mime_type,
             temperature: 0.3
           ) do
      generate_output(response, user_text)
    else
      {:error, reason} ->
        Logger.error("Erro ao classificar mensagem: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def classify_multimodal(binary, mime_type, user_text) do
    prompt_text =
      build_classification_prompt(user_text <> " (Analyze the attached media if provided)")

    # Upload a file
    {:ok, file} =
      Gemini.APIs.Files.upload_data(binary,
        mime_type: "image/png",
        display_name: "In-Memory Image"
      )

    # Wait for processing (videos/large files)
    {:ok, ready} = Gemini.APIs.Files.wait_for_processing(file.name)

    # Estrutura para o Gemini receber o binário + texto
    content_parts = [
      %{text: prompt_text},
      %{file_uri: ready.uri, mime_type: ready.mime_type}
    ]

    with {:ok, response} <-
           Gemini.generate(content_parts,
             response_json_schema: @response_schema,
             response_mime_type: @response_mime_type,
             temperature: 0.3
           ) do
      generate_output(response, user_text)
    else
      {:error, reason} ->
        Logger.error("Erro ao classificar mensagem: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Parses a raw AI classification data map into the message context.
  This is a pure function that can be used directly in tests.
  """
  def parse_classification_data(data, text) do
    message_type = parse_message_type(data["message_type"])

    %{
      message_type: message_type,
      transaction_data: data["transaction_data"],
      ai_response: data["ai_response"],
      original_text: text
    }
  end

  def process_financial_tip_request(context) do
    prompt = build_financial_tip_prompt(context.original_text)
    {:ok, response} = Gemini.generate(prompt)

    context |> Map.put(:ai_response, parse_text_response(response))
  end

  # region Internal

  defp parse_message_type("transaction"), do: :transaction
  defp parse_message_type("data_query"), do: :data_query
  defp parse_message_type("finance_tip"), do: :finance_tip
  defp parse_message_type("app_conversation"), do: :app_conversation
  defp parse_message_type("small_talk"), do: :small_talk
  defp parse_message_type(_), do: :unrelated

  @doc """
  Builds the AI classification prompt for the given user message and optional existing tags.
  Made public for testability.
  """
  def build_classification_prompt(text, existing_tags \\ []) do
    categories = Transaction.category_values() |> Enum.join("|")

    host =
      Application.fetch_env!(:fin_bot_elixir, FinBotElixirWeb.Endpoint)[:host] ||
        "http://localhost:4000"

    tags_hint =
      case existing_tags do
        [] ->
          ""

        tags ->
          existing = Enum.join(tags, ", ")

          "\nThe user already has these tags: [#{existing}]. Reuse an existing tag when the context is a close match.\n"
      end

    """
    You are FinBot, a personal finance assistant. You help users manage their finances by recording transactions,
    providing financial tips, and answering questions about their spending.

    Analyze the following message and classify it into exactly one of these types:
    - "transaction": a financial transaction to be recorded (expense or income with a clear amount)
    - "data_query": a question about the user's recorded financial data or spending history
    - "finance_tip": a question or request about personal finance tips, strategies, or habits
    - "app_conversation": a question or statement about using the app itself
    (e.g. "how do I delete a transaction?" or "how do I use this app?" or "how do I use FinBot?" or "what can you do?")
    - "small_talk": casual conversation not related to finance (e.g. "how's the weather?")
    - "unrelated": anything not related to personal finance or not related to the FinBot app (you)

    Message: "#{text}"
    #{tags_hint}
    Category mapping (accept names in any language and map to the correct internal label):
    - food / comida / alimentação / essen / nourriture / طعام → "food"
    - transport / transporte / fahrt / transport / نقل → "transport"
    - housing / moradia / wohnen / logement / سكن → "housing"
    - health / saúde / gesundheit / santé / صحة → "health"
    - education / educação / bildung / éducation / تعليم → "education"
    - entertainment / entretenimento / unterhaltung / divertissement → "entertainment"
    - shopping / compras / einkaufen / courses / تسوق → "shopping"
    - travel / viagem / reise / voyage / سفر → "travel"
    - utilities / utilidades / nebenkosten / services publics → "utilities"
    - subscriptions / assinaturas / abonnements → "subscriptions"
    - salary / salário / gehalt / salaire / راتب → "salary"
    - freelance / freela → "freelance"
    - investments / investimentos / investissements / استثمارات → "investments"
    - other / outro / sonstige / autre → "other"

    Return a JSON object with:
    {
      "message_type": "transaction|data_query|finance_tip|app_conversation|small_talk|unrelated",
      "transaction_data": {
        "amount": positive number,
        "description": short descriptive name (e.g. "Uber", "Salary"),
        "category": one of [#{categories}],
        "type": "expense|income",
        "tags": [] (only tags EXPLICITLY mentioned by the user in their message; empty list if none were mentioned)
      },
      "ai_response": helpful reply text for the user in the same language as the message ALWAYS.
    }

    Rules:
    - For "transaction": fill transaction_data and set ai_response to a short friendly confirmation in the same language as the user's message. Category must be one of [#{categories}] — use the mapping above to translate the user's category to the correct internal label; default to "other" if unsure. Type defaults to "expense" if unsure. Tags must only include labels that the user explicitly mentioned (e.g. the user wrote "tag: car" or "#groceries"); do NOT infer or invent tags. If the user did not mention any tags, return an empty list. When the user does mention tags, normalize them to lowercase and prefer reusing an existing tag over creating a similar new one.
    - For "finance_tip": set transaction_data to null and set ai_response to a helpful, practical finance tip or answer in the same language as the user's message.
    - For "app_conversation": set transaction_data to null and ai_response to a helpful answer
    about using the app. See instructions below.
    - For "small_talk": set transaction_data to null and ai_response to a friendly reply
    engaging with the user's message.
    - For "data_query" and "unrelated": set transaction_data to null and ai_response to null.

    IMPORTANT RULE: Always use the same language as the user's message in ai_response.
    IMPORTANT RULE: Always use casual, friendly language in ai_response. Use 1 or 2 emojis per response (but never more than 2).

    How to use FinBot (the app) for "app_conversation" messages:
    - User can record transactions by sending messages like "I spent $20 on groceries" or "I earned $1000 from freelancing".
    - User can ask questions about their finances like "How much did I spend on food last month?" or "What's my total income this year?"
    or "How many transactions have I recorded?"
    - User can ask for finance tips like "How can I save more money?"
    or "What's a good budgeting strategy?"
    - User can login and see a dashboard by asking related questions. When the user asks that, send them
    the link to their dashboard with the `linking_token` you have stored for them, in the format:
    "You can view your dashboard and manage your account here: #{host}/auth/google?token=<linking_token>"

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

  defp generate_output(response, original_text) do
    with {:ok, data} <- parse_response(response) do
      message_type = parse_message_type(data["message_type"])

      context = %{
        message_type: message_type,
        transaction_data: data["transaction_data"],
        ai_response: data["ai_response"],
        original_text: original_text
      }

      Logger.info(
        "Mensagem classificada como '#{message_type}': #{original_text}\n#{inspect(context)}"
      )

      {:ok, context}
    end
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

  # endregion
end
