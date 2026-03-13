defmodule FinBotElixir.Workers.MediaMessageWorker do
  @moduledoc """
  Oban worker that processes incoming WhatsApp image and audio messages.

  Downloads the media binary, classifies it with Gemini's multimodal API, and
  delegates the result to `FinBotElixir.MessageHandler` for the appropriate
  action.

  Oban manages retries automatically; the manual retry loop that previously
  lived in `Processor` is no longer needed here.
  """

  use Oban.Worker,
    queue: :messages,
    max_attempts: 3

  require Logger

  alias FinBotElixir.Accounts
  alias FinBotElixir.Gemini.Client
  alias FinBotElixir.MessageHandler
  alias FinBotElixir.WhatsApp.MediaClient

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"from" => sender_id, "type" => type} = args}) do
    Logger.info("[MEDIA] Processando mensagem de mídia do sender #{sender_id}")

    mime_type = if type == "image", do: "image/jpeg", else: "audio/ogg"

    with {:ok, user} <- Accounts.find_or_create_by_whatsapp(sender_id),
         {:ok, binary} <- MediaClient.download_media(args["url"]),
         {:ok, context} <- Client.classify_multimodal(binary, mime_type, args["caption"] || "") do
      context
        |> Map.put(:sender_id, sender_id)
        |> MessageHandler.handle_classified_message(user)
    end
  end
end
