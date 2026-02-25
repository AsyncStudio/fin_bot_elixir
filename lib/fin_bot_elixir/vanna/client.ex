defmodule FinBotElixir.Vanna.Client do
  require Logger

  def make_query(query_text) do

    body = %{
      
    }

    case Req.post("#{base_url}/api/vanna/v2/chat_poll", json: body, auth: {:bearer, token}) do
      {:ok, _response} ->
        :ok

      {:error, reason} ->
        Logger.warn(
          "Erro ao enviar mensagem WhatsApp para #{whatsapp_number}: #{inspect(reason)}"
        )

        :error
    end
  end

  defp base_url(), do: Application.fetch_env!(:fin_bot_elixir, :vanna)[:base_url]
end
