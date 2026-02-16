defmodule FinBot.Processor do
  alias FinBot.Gemini.Client
  alias FinBot.Financial.Transaction
  alias FinBot.Repo

  def handle_webhook_message(params) do
    # Dispara o processo em background
    Task.Supervisor.start_child(FinBot.TaskSupervisor, fn ->
      process_transaction(params)
    end)

    # Responde imediatamente pro Node/Zap
    :ok
  end

  defp process_transaction(%{"content" => content, "sender" => sender_id}) do
    with {:ok, extracted_data} <- Client.analyze_input(content) do
      # Aqui você buscaria o user_id real pelo sender_id (número do Zap)
      # Por enquanto, vamos simular um UUID fixo
      user_id = "seu-uuid-de-teste-aqui"

      attrs = Map.merge(extracted_data, %{
        "raw_input" => content,
        "user_id" => user_id
      })

      %Transaction{}
      |> Transaction.changeset(attrs)
      |> Repo.insert()

      # TODO: Enviar confirmação de volta para o Node.js (via Webhook ou Redis)
      IO.inspect(attrs, label: "Transação salva no FinBot")
    end
  end
end
