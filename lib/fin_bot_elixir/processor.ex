defmodule FinBotElixir.Processor do
  require Logger

  alias FinBotElixir.Gemini.Client
  alias FinBotElixir.Gemini.Interactions
  alias FinBotElixir.Financial
  alias FinBotElixir.Accounts

  @default_category "other"

  @max_retries 5
  @retry_delay_ms 5_000

  def handle_webhook_message(params) do
    Logger.info("Iniciando processador para msg do webhook: #{inspect(params)}")

    Task.Supervisor.start_child(FinBotElixir.TaskSupervisor, fn ->
      retry(fn -> process_message(params) end, @max_retries)
    end)

    # Responde imediatamente pro Node/Zap
    :ok
  end

  defp process_message(%{from: sender_id, type: type} = params) when type in [:image, :audio] do
    Logger.info(
      "[MEDIA] Iniciando processamento da mensagem do sender #{sender_id}: #{inspect(params)}"
    )

    {:ok, user} = Accounts.find_or_create_by_whatsapp(sender_id)

    # 1. Busca URL e baixa o binário
    # {:ok, url} = FinBotElixir.WhatsApp.MediaClient.get_media_url(params.media_id)
    {:ok, binary} = FinBotElixir.WhatsApp.MediaClient.download_media(params.url)

    # 2. Define o MIME type (simplificado para o exemplo)
    mime_type = if type == :image, do: "image/jpeg", else: "audio/ogg"

    # 3. Classifica com Multimodalidade
    with {:ok, context} <- Client.classify_multimodal(binary, mime_type, params[:caption] || "") do
      context = Map.put(context, :sender_id, sender_id)
      handle_classified_message(context, user)
    else
      {:error, reason} ->
        Logger.error(
          "[MEDIA] Erro ao classificar mensagem para sender #{sender_id}: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  defp process_message(%{from: sender_id, text: content}) do
    Logger.info("Iniciando processamento da mensagem do sender #{sender_id}: #{content}")

    {:ok, user} = Accounts.find_or_create_by_whatsapp(sender_id)
    existing_tags = Financial.list_all_tag_names_for_user(user.id)

    with {:ok, context} <- Client.classify_message(content, existing_tags) do
      context
      |> Map.put(:sender_id, sender_id)
      |> Map.put(:existing_tags, existing_tags)
      |> handle_classified_message(user)
    else
      {:error, reason} ->
        Logger.error("Erro ao classificar mensagem para sender #{sender_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # region: Classification

  defp handle_classified_message(%{message_type: :transaction} = context, user) do
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

  defp handle_classified_message(%{message_type: :finance_tip} = context, user) do
    context
    |> Client.process_financial_tip_request()
    |> Interactions.handle_message_context(user, nil)
  end

  defp handle_classified_message(%{message_type: :data_query} = context, user) do
    # TODO: Handle Data query AI
    Interactions.handle_message_context(context, user, nil)
    :ok
  end

  defp handle_classified_message(context, user) do
    Interactions.handle_message_context(context, user, nil)
    :ok
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

  # endregion
  # region: Retry

  defp retry(fun, retries_left, attempt \\ 1)

  defp retry(_fun, 0, attempt) do
    Logger.error("Processamento falhou após #{attempt - 1} tentativas, desistindo.")
  end

  defp retry(fun, retries_left, attempt) do
    case fun.() do
      :ok ->
        :ok

      {:error, :no_retry} ->
        :ok

      {:error, reason} ->
        Logger.warning(
          "Tentativa #{attempt} falhou: #{inspect(reason)}. Tentativas restantes: #{retries_left - 1}"
        )

        Process.sleep(@retry_delay_ms)
        retry(fun, retries_left - 1, attempt + 1)
    end
  rescue
    exception ->
      Logger.warning(
        "Tentativa #{attempt} falhou com exceção: #{inspect(exception)}. Tentativas restantes: #{retries_left - 1}"
      )

      Process.sleep(@retry_delay_ms)
      retry(fun, retries_left - 1, attempt + 1)
  end

  # endregion
end
