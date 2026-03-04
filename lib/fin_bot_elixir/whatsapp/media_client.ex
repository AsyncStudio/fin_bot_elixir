# lib/fin_bot_elixir/whatsapp/media_client.ex
defmodule FinBotElixir.WhatsApp.MediaClient do
  def get_media_url(media_id) do
    base_url = FinBotElixir.WhatsApp.Client.base_url()
    token = FinBotElixir.WhatsApp.Client.token()
    url = "#{base_url}/#{media_id}"

    with {:ok, response} <- Req.get(url, auth: {:bearer, token}) do
      {:ok, response.body["url"]}
    end
  end

  def download_media(url) do
    token = FinBotElixir.WhatsApp.Client.token()

    with {:ok, response} <- Req.get(url, auth: {:bearer, token}) do
      # Retorna o binário do arquivo
      {:ok, response.body}
    end
  end
end
