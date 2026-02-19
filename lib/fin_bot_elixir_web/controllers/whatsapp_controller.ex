defmodule FinBotElixirWeb.WhatsappController do
  require Logger
  import Dotenvy

  use FinBotElixirWeb, :controller
  alias FinBotElixir.Processor

  def verify(conn, %{"hub.mode" => "subscribe", "hub.challenge" => challenge, "hub.verify_token" => token}) do
    if token == env!("WHATSAPP_VERIFY_TOKEN", :string) do
      send_resp(conn, 200, challenge)
    else
      send_resp(conn, 403, "Forbidden")
    end
  end

  def receive(conn, params) do
    # A estrutura da Meta é profunda, vamos extrair o essencial
    case extract_message(params) do
      %{from: from, text: text} ->
        # Rodamos nossa lógica de Shadow User e Gemini de forma assíncrona
        Processor.handle_webhook_message(from, text)
        send_resp(conn, 200, "")

      _ ->
        Logger.warn("Webhook recebido com formato inesperado: #{inspect(params)}")
        send_resp(conn, 200, "") # Sempre responda 200 para a Meta não reenviar
    end
  end

  defp extract_message(%{"entry" => [%{"changes" => [%{"value" => %{"messages" => [msg]}}]}]}) do
    %{from: msg["from"], text: msg["text"]["body"]}
  end

  defp extract_message(_), do: nil
end
