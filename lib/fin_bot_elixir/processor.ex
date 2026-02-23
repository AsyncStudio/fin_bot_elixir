defmodule FinBotElixir.Processor do
  require Logger

  alias FinBotElixir.Repo
  alias FinBotElixir.Gemini.Client
  alias FinBotElixir.Gemini.Interactions
  alias FinBotElixir.Financial
  alias FinBotElixir.Financial.Transaction
  alias FinBotElixir.Accounts

  @max_retries 5
  @retry_delay_ms 5_000

  def handle_webhook_message(params) do
    # Dispara o processo em background
    Logger.info("Recebida nova mensagem do webhook: #{inspect(params)}")

    Task.Supervisor.start_child(FinBotElixir.TaskSupervisor, fn ->
      retry(fn -> process_transaction(params) end, @max_retries)
    end)

    # Responde imediatamente pro Node/Zap
    :ok
  end

  defp retry(fun, retries_left, attempt \\ 1)

  defp retry(_fun, 0, attempt) do
    Logger.error("Processamento falhou após #{attempt - 1} tentativas, desistindo.")
  end

  defp retry(fun, retries_left, attempt) do
    case fun.() do
      :ok ->
        :ok

      {:error, :not_a_transaction} ->
        # Mensagem não é uma transação, não há necessidade de tentar novamente
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

  defp process_transaction(%{from: sender_id, text: content}) do
    Logger.info("Iniciando processamento da mensagem do sender #{sender_id}: #{content}")

    {:ok, user} = Accounts.find_or_create_by_whatsapp(sender_id)

    with {:ok, extracted_data} <- Client.analyze_input(content) do
      # Aqui você buscaria o user_id real pelo sender_id (número do Zap)
      # Por enquanto, vamos simular um UUID fixo

      attrs =
        Map.merge(extracted_data, %{
          "raw_input" => content,
          "user_id" => user.id,
          "category" => extracted_data["category"] || Transaction.category_values() |> List.last(),
        })

      Logger.debug("Dados extraídos para criação da transação: #{inspect(attrs)}", %{attrs: attrs})

      with {:ok, transaction} <- Financial.create_transaction_for_user(user.id, attrs) do
        Logger.info("Transação salva no FinBot para o sender #{sender_id}", %{transaction: attrs})
        process_response(transaction)
      else
        {:error, reason} ->
          Logger.error("Erro ao criar transação para sender #{sender_id}: #{inspect(reason)}", %{
            error: reason,
            attrs: attrs
          })

          {:error, reason}
      end
    else
      {:error, :not_a_transaction} ->
        Interactions.process_error(sender_id)
        {:error, :not_a_transaction}

      {:error, reason} ->
        Interactions.process_error(sender_id)
        {:error, reason}
    end
  end

  defp process_response(%Transaction{} = transaction) do
    # TODO: Enviar confirmação de volta para o Node.js (via Webhook ou Redis)
    Interactions.process_response(transaction)
    :ok
  end
end
