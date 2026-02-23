defmodule FinBotWeb.Helpers.WhatsApp do
  def share_link(phone, message \\ "") do
    base = "https://wa.me/#{String.replace(phone, ~r/\D/, "")}"
    if message != "", do: base <> "?text=#{URI.encode(message)}", else: base
  end
end
