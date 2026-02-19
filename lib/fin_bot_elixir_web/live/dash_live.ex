defmodule FinBotElixirWeb.DashLive do
  use FinBotElixirWeb, :live_view
  alias FinBotElixir.Financial

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    {:ok, assign(socket, user_id: user.id, user_name: user.full_name)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  # Lógica para a tela de LISTA (dashboard principal)
  defp apply_action(socket, :index, _params) do
    summary = Financial.dashboard_summary(socket.assigns.user_id)

    now = Date.utc_today()
    month_label = Calendar.strftime(now, "%B %Y")

    assign(socket,
      page_title: "My Finances",
      month_label: month_label,
      expense_categories: summary.expense_categories,
      income_categories: summary.income_categories,
      total_expenses: summary.total_expenses,
      total_income: summary.total_income,
      net_balance: summary.net_balance
    )
  end

  # Lógica para a tela de EXTRATO
  defp apply_action(socket, :show, %{"name" => name}) do
    transactions = Financial.list_by_category(socket.assigns.user_id, name)

    category_type =
      case List.first(transactions) do
        nil -> "expense"
        t -> t.type
      end

    category_total =
      transactions
      |> Enum.reduce(Decimal.new(0), &Decimal.add(&1.amount, &2))

    now = Date.utc_today()
    month_label = Calendar.strftime(now, "%B %Y")

    assign(socket,
      page_title: "#{name}",
      category_name: name,
      category_type: category_type,
      category_total: category_total,
      transaction_count: length(transactions),
      month_label: month_label,
      transactions: transactions
    )
  end

  @doc """
  Formats a Decimal as a currency string (R$ 1.234,56).
  """
  def format_currency(amount) do
    amount
    |> Decimal.round(2)
    |> Decimal.to_string()
    |> format_number_br()
  end

  defp format_number_br(str) do
    case String.split(str, ".") do
      [int_part, dec_part] ->
        int_formatted = format_integer_part(int_part)
        "#{int_formatted},#{String.pad_trailing(dec_part, 2, "0")}"

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
end
