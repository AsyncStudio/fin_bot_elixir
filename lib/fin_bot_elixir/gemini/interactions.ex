defmodule FinBotElixir.Gemini.Interactions do
  alias FinBotElixir.WhatsApp.Client
  alias FinBotElixir.Financial.Transaction
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

  @income_responses [
    "Receita registrada! Ótimo ver dinheiro entrando. 💰",
    "Anotado seu ganho! Lembre-se de equilibrar receitas e despesas para manter as finanças saudáveis. ⚖️",
    "Ganho adicionado! Se quiser, posso te ajudar a analisar suas fontes de renda depois. 🤖"
  ]

  @failed_responses [
    "Não consegui entender essa mensagem como uma transação válida. Pode reformular?",
    "Parece que essa mensagem não contém um gasto ou receita claro. Tente ser mais específico!",
    "Ops, não consegui extrair uma transação dessa mensagem. Certifique-se de incluir um valor e uma descrição clara."
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
  def handle_message_context(%{message_type: :data_query} = context, user, _transaction) do
    ai_response = Map.get(context, :ai_response)

    response =
      if is_binary(ai_response) and ai_response != "" do
        ai_response
      else
        Gettext.gettext(FinBotElixirWeb.Gettext, @data_query_response_msgid)
      end

    send_message(user, response)
  end

  ## UNRELATED
  def handle_message_context(%{message_type: :unrelated}, user, _transaction) do
    response = Gettext.gettext(FinBotElixirWeb.Gettext, @unrelated_response_msgid)
    send_message(user, response)
  end

  def handle_message_context(context, user, _transaction)
      when is_binary(context.ai_response) and context.ai_response != "" do
    send_message(user, context.ai_response)
  end

  # Default handler
  def handle_message_context(_context, user, _transaction) do
    response = Enum.random(@error_responses)
    send_message(user, response)
  end

  # endregion

  # region: Msg Switch

  defp smart_process(%Transaction{} = transaction, count, _ai_response) when count <= 1 do
    welcome_and_process(transaction.user, transaction.raw_input)
  end

  defp smart_process(%Transaction{} = transaction, count, _ai_response) when count == 5 do
    process_with_cta(transaction.user, transaction.raw_input)
  end

  defp smart_process(_transaction, _count, ai_response) when not is_nil(ai_response) do
    ai_response
  end

  defp smart_process(%Transaction{type: "expense"}, _count, _ai_response) do
    process_return_random(@expense_responses)
  end

  defp smart_process(%Transaction{type: "income"}, _count, _ai_response) do
    process_return_random(@income_responses)
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

  defp welcome_and_process(user, _text) do
    """
    Salve, #{user.full_name || ""}! 👋
    Já anotei seu primeiro gasto aqui.

    Eu sou o FinBot e vou organizar suas finanças por aqui.
    Não precisa de cadastro agora, só vai mandando os gastos!
    """
  end

  defp process_with_cta(user, _text) do
    """
    Boa! Mais um anotado. ✅

    Você já registrou 5 gastos! Que tal ver como está seu saldo no mês?
    Crie sua conta rapidinho com o Google para liberar o Dashboard:
    👉 https://finbot.app/join/#{user.linking_token}
    """
  end

  defp process_return_random(list) do
    Enum.random(list)
  end

  # endregion
end
