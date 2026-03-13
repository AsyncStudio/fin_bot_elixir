defmodule FinBotElixir.Processor do
  @moduledoc """
  Public facade for incoming WhatsApp webhook messages.

  Converts the raw webhook params into Oban job arguments and enqueues the
  appropriate worker.  Returns `:ok` immediately so the webhook endpoint can
  respond without waiting for processing to complete.

  Retry logic is handled automatically by Oban — see each worker module for
  the configured `max_attempts` value.
  """

  require Logger

  alias FinBotElixir.Workers.MediaMessageWorker
  alias FinBotElixir.Workers.TextMessageWorker

  @doc """
  Enqueues an Oban job to process the incoming webhook message asynchronously.
  Always returns `:ok` so the HTTP response can be sent immediately.
  """
  def handle_webhook_message(%{type: type, from: sender_id} = params)
      when type in [:image, :audio] do
    Logger.info("Enfileirando mensagem de mídia do webhook para sender #{sender_id}")

    %{
      "from" => sender_id,
      "type" => Atom.to_string(type),
      "url" => params[:url],
      "media_id" => params[:media_id],
      "caption" => params[:caption]
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
    |> MediaMessageWorker.new()
    |> Oban.insert()

  @doc """
    Main entry point for processing incoming messages from the WhatsApp webhook.
    Spawns a supervised task to handle the message asynchronously, with retry logic.
  """
  def handle_webhook_message(params) do
    Logger.info("Iniciando processador para msg do webhook: #{inspect(params)}")

    Task.Supervisor.start_child(FinBotElixir.TaskSupervisor, fn ->
      retry(fn -> process_message(params) end, @max_retries)
    end)

    :ok
  end

  def handle_webhook_message(%{from: sender_id, text: text}) do
    Logger.info("Enfileirando mensagem de texto do webhook para sender #{sender_id}")

    %{"from" => sender_id, "text" => text}
    |> TextMessageWorker.new()
    |> Oban.insert()

    :ok
  end
end
