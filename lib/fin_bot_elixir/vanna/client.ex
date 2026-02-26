defmodule FinBotElixir.Vanna.Client do
  require Logger

  def make_query(query_text) do

    body = %{
      "message" => query_text,
      "conversation_id" => "default_conversation",
      "metadata" => %{}
    }
    token = ""

    case Req.post("#{base_url()}/api/vanna/v2/chat_poll", json: body, auth: {:bearer, token}) do
      {:ok, _response} ->
        :ok

      {:error, reason} ->
        Logger.warn(
          "Erro ao tentar comunicar com o serviço vanna: #{inspect(reason)}"
        )

        :error
    end
  end

  defp base_url(), do: Application.fetch_env!(:fin_bot_elixir, :vanna)[:base_url]
end
