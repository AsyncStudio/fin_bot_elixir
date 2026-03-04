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
    Logger.info("[MEDIA] Iniciando processamento da mensagem do sender #{sender_id}: #{inspect(params)}")
    {:ok, user} = Accounts.find_or_create_by_whatsapp(sender_id)

    # 1. Busca URL e baixa o binário
    {:ok, url} = FinBotElixir.WhatsApp.MediaClient.get_media_url(params.media_id)
    {:ok, binary} = FinBotElixir.WhatsApp.MediaClient.download_media(url)

    # 2. Define o MIME type (simplificado para o exemplo)
    mime_type = if type == :image, do: "image/jpeg", else: "audio/ogg"

    # 3. Classifica com Multimodalidade
    with {:ok, context} <- Client.classify_multimodal(binary, mime_type, params[:caption] || "") do
      context = Map.put(context, :sender_id, sender_id)
      handle_classified_message(context, user)
    else
      {:error, reason} ->
        Logger.error("[MEDIA] Erro ao classificar mensagem para sender #{sender_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp process_message(%{from: sender_id, text: content}) do
    Logger.info("Iniciando processamento da mensagem do sender #{sender_id}: #{content}")

    {:ok, user} = Accounts.find_or_create_by_whatsapp(sender_id)

    with {:ok, context} <- Client.classify_message(content) do
      context = Map.put(context, :sender_id, sender_id)
      handle_classified_message(context, user)
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
        "category" =>
          transaction_data["category"] || @default_category
      })

    Logger.debug("Dados extraídos para criação da transação: #{inspect(attrs)}")

    with {:ok, transaction} <- Financial.create_transaction_for_user(user.id, attrs) do
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
