defmodule FinBotElixir.WhatsApp.Client do
  require Logger

  def send_message(text, whatsapp_number) do
    phone_id = phone_id()
    base_url = base_url()
    token = token()

    url = "#{base_url}/#{phone_id}/messages"

    Logger.info("Enviando mensagem para #{whatsapp_number}: #{text}")

    Logger.debug(
      "Detalhes do envio #{inspect(%{url: url, whatsapp_number: whatsapp_number, text: text})}"
    )

    body = %{
      messaging_product: "whatsapp",
      recipient_type: "individual",
      to: whatsapp_number,
      type: "text",
      text: %{body: text}
    }

    case Req.post(url, json: body, auth: {:bearer, token}) do
      {:ok, _response} ->
        :ok

      {:error, reason} ->
        Logger.warning(
          "Erro ao enviar mensagem WhatsApp para #{whatsapp_number}: #{inspect(reason)}"
        )

        :error
    end
  end

  def token, do: Application.fetch_env!(:fin_bot_elixir, :whatsapp)[:token]
  def base_url, do: Application.fetch_env!(:fin_bot_elixir, :whatsapp)[:base_url]
  def phone_id, do: Application.fetch_env!(:fin_bot_elixir, :whatsapp)[:phone_id]
end
