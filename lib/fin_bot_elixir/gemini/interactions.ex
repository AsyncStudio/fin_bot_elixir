defmodule FinBotElixir.Gemini.Interactions do

  alias FinBotElixir.WhatsApp.Client
  alias FinBotElixir.Financial.Transaction
  alias FinBotElixir.Financial

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
    "Ganho adicionado! Se quiser, posso te ajudar a analisar suas fontes de renda depois. 🤖",
  ]

  @failed_responses [
    "Não consegui entender essa mensagem como uma transação válida. Pode reformular?",
    "Parece que essa mensagem não contém um gasto ou receita claro. Tente ser mais específico!",
    "Ops, não consegui extrair uma transação dessa mensagem. Certifique-se de incluir um valor e uma descrição clara."
  ]

  # region: Msg Switch

  def process_response(%Transaction{} = transaction) do
    count = Financial.count_user_transactions(transaction.user_id)
    smart_process(transaction, count)
      |> Client.send_message(transaction.user.whatsapp_number)
  end

  def process_error(whatsapp_number) do
    process_return_random(@failed_responses)
      |> Client.send_message(whatsapp_number)
  end

  defp smart_process(%Transaction{} = transaction, count) when count <= 1 do
    welcome_and_process(transaction.user_id, transaction.raw_input)
  end

  defp smart_process(%Transaction{} = transaction, count) when count == 5 do
    process_with_cta(transaction.user_id, transaction.raw_input)
  end

  defp smart_process(%Transaction{type: "expense"} = transaction, _count) do
    process_return_random(@expense_responses)
  end

  defp smart_process(%Transaction{type: "income"} = transaction, _count) do
    process_return_random(@income_responses)
  end

  # endregion

  # region: Helpers

  defp welcome_and_process(user, text) do
    # TODO: welcome message
    """
    Salve, #{user.full_name}! 👋
    Já anotei seu primeiro gasto aqui.

    Eu sou o FinBot e vou organizar suas finanças por aqui.
    Não precisa de cadastro agora, só vai mandando os gastos!
    """
  end

  defp process_with_cta(user, text) do
    # TODO: CTA
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
