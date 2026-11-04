defmodule FinBotElixir.Gemini.Interactions do
  alias FinBotElixir.WhatsApp.Client
  alias FinBotElixir.Financial

  @data_query_response_msgid "This capability is under construction. Hold fast! 🔧"
  @unrelated_response_msgid "This topic is unrelated. Please talk only about finances. 💰"
  @finance_tip_fallback_msgid "I was unable to generate advice at this time. Please try again."

  @expense_responses [
    "Anotado! Esse gasto vai pesar no seu orçamento esse mês. 😬",
    "Gasto registrado! Lembre-se de revisar seus gastos no final do mês para manter o controle. 📊",
    "Feito! Cada gasto conta, continue anotando para ter uma visão clara das suas finanças. 💡",
    "Gasto adicionado! Se quiser, posso te ajudar a categorizar ou analisar seus gastos depois. 🤖",
    "Anotação feita! Manter um registro dos gastos é o primeiro passo para uma vida financeira saudável. 🌱"
  ]

  @error_responses [
    "Houve um erro ao processar sua mensagem. Tente novamente mais tarde."
  ]

  # region: Context dispatcher

  @doc """
  Handles the appropriate response for each classified message type.
  Receives the message context, the user, and optionally the saved transaction.
  """
  def handle_message_context(%{message_type: :transaction} = context, user, transaction) do
    base_response = context.ai_response || Enum.random(@expense_responses)

    response =
      if transaction do
        weekly_total =
          Financial.weekly_category_total(transaction.user_id, transaction.category, transaction.type)

        weekly_suffix = format_weekly_total(weekly_total, transaction.type)
        base_response <> "\n\n" <> weekly_suffix
      else
        base_response
      end

    send_message(user, response)
  end

  ## FINANCE TIP
  def handle_message_context(%{message_type: :finance_tip} = context, user, _transaction) do
    response =
      context.ai_response || Gettext.gettext(FinBotElixirWeb.Gettext, @finance_tip_fallback_msgid)

    send_message(user, response)
  end

  ## DATA QUERY
  def handle_message_context(%{message_type: :data_query}, user, _transaction) do
    response = Gettext.gettext(FinBotElixirWeb.Gettext, @data_query_response_msgid)
    send_message(user, response)
  end

  ## UNRELATED
  def handle_message_context(%{message_type: :unrelated}, user, _transaction) do
    response = Gettext.gettext(FinBotElixirWeb.Gettext, @unrelated_response_msgid)
    send_message(user, response)
  end

  # Default handler
  def handle_message_context(context, user, _transaction)
      when is_binary(context.ai_response) and context.ai_response != "" do
    send_message(user, context.ai_response)
  end

  # Error handler
  def handle_message_context(_context, user, _transaction) do
    response = Enum.random(@error_responses)
    send_message(user, response)
  end

  # endregion

  # region: Helpers

  defp format_weekly_total(total, "expense") do
    "💡 Você gastou R$ #{format_currency(total)} nessa categoria nos últimos 7 dias."
  end

  defp format_weekly_total(total, _type) do
    "💰 Você recebeu R$ #{format_currency(total)} nessa categoria nos últimos 7 dias."
  end

  defp format_currency(amount) do
    amount
    |> Decimal.round(2)
    |> Decimal.to_string()
    |> format_number_br()
  end

  defp format_number_br(str) do
    case String.split(str, ".") do
      [int_part, dec_part] ->
        "#{format_integer_part(int_part)},#{String.pad_trailing(dec_part, 2, "0")}"

      [int_part] ->
        "#{format_integer_part(int_part)},00"
    end
  end

  defp format_integer_part(str) do
    {sign, digits} =
      if String.starts_with?(str, "-"),
        do: {"-", String.trim_leading(str, "-")},
        else: {"", str}

    formatted =
      digits
      |> String.graphemes()
      |> Enum.reverse()
      |> Enum.chunk_every(3)
      |> Enum.join(".")
      |> String.reverse()

    sign <> formatted
  end

  defp send_message(user, message) do
    message
    |> String.replace(~r/<linking_token>/, user.linking_token || "")
    |> Client.send_message(user.whatsapp_number)
  end

  # endregion
end
