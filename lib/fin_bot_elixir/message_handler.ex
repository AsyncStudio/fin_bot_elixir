defmodule FinBotElixir.MessageHandler do
  @moduledoc """
  Core message-handling logic shared by all message workers.

  This module is responsible for dispatching the classified message context to
  the appropriate handler (create transaction, generate finance tip, etc.) and
  sending the WhatsApp reply back to the user.  It intentionally contains no
  async or retry concerns — those are owned by the Oban workers.
  """

  require Logger

  alias FinBotElixir.Financial
  alias FinBotElixir.Gemini.Client
  alias FinBotElixir.Gemini.Interactions

  @default_category "other"

  @doc """
  Dispatches a classified message context to the appropriate handler and sends a
  WhatsApp reply.  Returns `:ok` on success or `{:error, reason}` on failure.
  """
  def handle_classified_message(%{message_type: :transaction} = context, user) do
    transaction_data = context.transaction_data || %{}

    attrs =
      Map.merge(transaction_data, %{
        "raw_input" => context.original_text,
        "user_id" => user.id,
        "category" => transaction_data["category"] || @default_category
      })

    Logger.debug("Dados extraídos para criação da transação: #{inspect(attrs)}")

    with {:ok, transaction} <- Financial.create_transaction_for_user(user.id, attrs) do
      apply_tags(
        transaction,
        transaction_data["tags"] || [],
        Map.get(context, :existing_tags, [])
      )

      Logger.info("Transação salva no FinBot para o sender #{context.sender_id}")
      Interactions.handle_message_context(context, user, transaction)
      :ok
    else
      {:error, reason} ->
        Logger.error(
          "Erro ao criar transação para sender #{context.sender_id}: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  def handle_classified_message(%{message_type: :finance_tip} = context, user) do
    context
    |> Client.process_financial_tip_request()
    |> Interactions.handle_message_context(user, nil)
  end

  def handle_classified_message(%{message_type: :data_query} = context, user) do
    Logger.info("Processando data_query para sender #{context.sender_id}")

    result =
      with {:ok, sql} <- Client.generate_sql(context.original_text, user.id),
           :ok <- validate_sql_scope(sql, user.id),
           {:ok, results} <- Financial.execute_raw_query(sql),
           {:ok, human_response} <- Client.humanize_results(results, context.original_text) do
        {:ok, human_response}
      else
        {:error, reason} ->
          Logger.error(
            "Erro ao processar data_query para sender #{context.sender_id}: #{inspect(reason)}"
          )

          {:error, reason}
      end

    updated_context =
      case result do
        {:ok, human_response} -> Map.put(context, :ai_response, human_response)
        {:error, _reason} -> context
      end

    Interactions.handle_message_context(updated_context, user, nil)
    :ok
  end

  def handle_classified_message(context, user) do
    Interactions.handle_message_context(context, user, nil)
    :ok
  end

  # ---------------------------------------------------------------------------
  # Tag helpers
  # ---------------------------------------------------------------------------

  # Validates that the AI-generated SQL references the expected user_id to prevent
  # data leakage across users due to prompt injection or AI hallucination.
  defp validate_sql_scope(sql, user_id) do
    if String.contains?(sql, to_string(user_id)) do
      :ok
    else
      Logger.error("validate_sql_scope: SQL does not contain user_id #{user_id}, rejecting")
      {:error, :missing_user_scope}
    end
  end

  # Applies AI-suggested tags to a transaction, normalizing each tag against
  # already-existing user tags to avoid near-duplicate tags (e.g. "car" vs "cars").
  defp apply_tags(_transaction, [], _existing_tags), do: :ok

  defp apply_tags(transaction, tags, existing_tags) when is_list(tags) do
    Logger.info(
      "Aplicando tags sugeridas pela IA para a transação #{transaction.id}: #{inspect(tags)}"
    )

    Enum.each(tags, fn raw_tag ->
      tag_name = normalize_tag_name(raw_tag, existing_tags)
      Financial.add_tag_to_transaction(transaction, tag_name)
    end)
  end

  # Returns the best-matching existing tag name when the similarity is high
  # enough (Jaro distance >= 0.9), otherwise returns the normalized input tag.
  defp normalize_tag_name(tag, existing_tags) do
    normalized = tag |> String.downcase() |> String.trim()

    match =
      Enum.find(existing_tags, fn existing ->
        existing_lower = String.downcase(existing)
        existing_lower == normalized or String.jaro_distance(existing_lower, normalized) >= 0.9
      end)

    match || normalized
  end
end
