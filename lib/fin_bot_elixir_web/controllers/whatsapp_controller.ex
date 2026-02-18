defmodule FinBotElixirWeb.WhatsappController do
  use FinBotElixirWeb, :controller
  alias FinBotElixir.Processor

  def receive(conn, params) do
    # O params aqui já chega como o JSON vindo do Node.js
    # Ex: %{"sender" => "55489...", "content" => "Gastei 50 no mercado", "message_type" => "text"}

    case Processor.handle_webhook_message(params) do
      :ok ->
        # Retornamos 202 (Accepted) para indicar que o processamento começou
        send_resp(conn, 202, "")

      _error ->
        # Caso algo dê muito errado na orquestração inicial
        send_resp(conn, 500, "Internal Server Error")
    end
  end
end
