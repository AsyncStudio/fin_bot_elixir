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
    "Houve um erro ao processar sua mensagem. Tente novamente mais tarde.",
  ]

  # region: Context dispatcher

  @doc """
  Handles the appropriate response for each classified message type.
  Receives the message context, the user, and optionally the saved transaction.
  """
  def handle_message_context(%{message_type: :transaction} = context, user, transaction) do
    response = context.ai_response || Enum.random(@expense_responses)
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

  def handle_message_context(context, user, _transaction) when context.ai_response != "" do
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
