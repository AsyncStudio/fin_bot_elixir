defmodule FinBotElixir.WhatsApp.Client do
  require Logger
  import Dotenvy

  def send_message(text, whatsapp_number) do
    phone_id = phone_id()
    base_url = base_url()
    token = token()

    url = "#{@base_url}/#{phone_id}/messages"

    Logger.info("Enviando mensagem para #{whatsapp_number}: #{text}")
    Logger.debug("Detalhes do envio #{inspect(%{url: url, token: token, whatsapp_number: whatsapp_number, text: text})}")

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
        Logger.warn("Erro ao enviar mensagem WhatsApp para #{whatsapp_number}: #{inspect(reason)}")
        :error
    end
  end

  defp base_url, do: env!("FACEBOOK_API_URL", :string)
  defp token, do: env!("WHATSAPP_ACCESS_TOKEN", :string)
  defp phone_id, do: env!("WHATSAPP_PHONE_NUMBER_ID", :string)
end
