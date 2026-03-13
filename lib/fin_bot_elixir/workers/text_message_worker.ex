defmodule FinBotElixir.Workers.TextMessageWorker do
  @moduledoc """
  Oban worker that processes incoming WhatsApp text messages.

  Classifies the text with Gemini AI and delegates the result to
  `FinBotElixir.MessageHandler` for the appropriate action (save transaction,
  finance tip, data query, etc.).

  Oban manages retries automatically; the manual retry loop that previously
  lived in `Processor` is no longer needed here.
  """

  use Oban.Worker,
    queue: :messages,
    max_attempts: 5

  require Logger

  alias FinBotElixir.Accounts
  alias FinBotElixir.Financial
  alias FinBotElixir.Gemini.Client
  alias FinBotElixir.MessageHandler

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"from" => sender_id, "text" => text}}) do
    Logger.info("Processando mensagem de texto do sender #{sender_id}: #{text}")

    with {:ok, user} <- Accounts.find_or_create_by_whatsapp(sender_id),
         existing_tags = Financial.list_all_tag_names_for_user(user.id),
         {:ok, context} <- Client.classify_message(text, existing_tags) do
      context
        |> Map.put(:sender_id, sender_id)
        |> Map.put(:existing_tags, existing_tags)
        |> MessageHandler.handle_classified_message(user)
    end
  end
end
