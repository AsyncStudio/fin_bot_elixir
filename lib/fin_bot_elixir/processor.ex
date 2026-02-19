defmodule FinBotElixir.Processor do
  require Logger

  alias FinBotElixir.Repo
  alias FinBotElixir.Gemini.Client
  alias FinBotElixir.Gemini.Interactions
  alias FinBotElixir.Financial
  alias FinBotElixir.Financial.Transaction
  alias FinBotElixir.Accounts

  def handle_webhook_message(params) do
    # Dispara o processo em background
    Logger.info("Recebida nova mensagem do webhook: #{inspect(params)}")

    Task.Supervisor.start_child(FinBotElixir.TaskSupervisor, fn ->
      process_transaction(params)
    end)

    # Responde imediatamente pro Node/Zap
    :ok
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
          "category" => extracted_data["category"] || "Outros"
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
      end
    else
      {:error, :not_a_transaction} ->
        # Logger.info("Mensagem do sender #{sender_id} não foi analisada como transação: #{content}")
        Interactions.process_error(sender_id)

      {:error, reason} ->
        # Logger.error("Erro ao analisar mensagem do sender #{sender_id}: #{inspect(reason)}")
        Interactions.process_error(sender_id)
    end
  end

  defp process_response(%Transaction{} = transaction) do
    # TODO: Enviar confirmação de volta para o Node.js (via Webhook ou Redis)
    return_text = Interactions.process_response(transaction)
  end
end
