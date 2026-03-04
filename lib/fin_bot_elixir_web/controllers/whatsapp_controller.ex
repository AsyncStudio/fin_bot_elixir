defmodule FinBotElixirWeb.WhatsappController do
  require Logger
  import Dotenvy

  use FinBotElixirWeb, :controller
  alias FinBotElixir.Processor

  def verify(conn, %{
        "hub.mode" => "subscribe",
        "hub.challenge" => challenge,
        "hub.verify_token" => token
      }) do
    if token == "fin_BOT-verify-token%$" do
      send_resp(conn, 200, challenge)
    else
      send_resp(conn, 403, "Forbidden")
    end
  end

  def receive(conn, params) do
    Logger.info("Recebida nova mensagem do webhook: #{inspect(params)}")
    # A estrutura da Meta é profunda, vamos extrair o essencial
    case extract_message(params) do
      %{from: from, text: text} ->
        # Rodamos nossa lógica de Shadow User e Gemini de forma assíncrona
        Processor.handle_webhook_message(%{from: from, text: text})
        send_resp(conn, 200, "")

      _ ->
        Logger.warn("Webhook recebido com formato inesperado: #{inspect(params)}")
        # Sempre responda 200 para a Meta não reenviar
        send_resp(conn, 200, "")
    end
  end

  defp extract_message(%{"entry" => [%{"changes" => [%{"value" => %{"messages" => [msg]}}]}]}) do
    case msg["type"] do
      "text" ->
        %{from: msg["from"], text: msg["text"]["body"], type: :text}

      "image" ->
        %{from: msg["from"], media_id: msg["image"]["id"], caption: msg["image"]["caption"], type: :image}

      "audio" ->
        %{from: msg["from"], media_id: msg["audio"]["id"], type: :audio}

      _ -> nil
    end
  end

  defp extract_message(_), do: nil
end
