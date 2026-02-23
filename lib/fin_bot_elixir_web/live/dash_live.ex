defmodule FinBotElixirWeb.DashLive do
  use FinBotElixirWeb, :live_view
  alias FinBotElixir.Financial
  alias FinBotElixir.Financial.Transaction

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
    categories = Transaction.categories()

    expense_categories = build_category_cards(categories, summary.expense_categories, "expense")
    income_categories = build_category_cards(categories, summary.income_categories, "income")

    now = Date.utc_today()
    month_label = Calendar.strftime(now, "%B %Y")

    assign(socket,
      page_title: "Minhas Finanças",
      month_label: month_label,
      expense_categories: expense_categories,
      income_categories: income_categories,
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
      transactions: transactions,
      all_categories: Transaction.categories(),
      editing_id: nil,
      edit_form: nil,
      confirm_delete_id: nil
    )
  end

  @impl true
  def handle_event("edit_transaction", %{"id" => id}, socket) do
    transaction = Financial.get_transaction_for_user!(id, socket.assigns.user_id)
    form = to_form(Financial.change_transaction(transaction), as: :transaction)
    {:noreply, assign(socket, editing_id: id, edit_form: form)}
  end

  @impl true
  def handle_event("cancel_edit", _params, socket) do
    {:noreply, assign(socket, editing_id: nil, edit_form: nil)}
  end

  @impl true
  def handle_event("save_transaction", %{"transaction" => params}, socket) do
    with editing_id when not is_nil(editing_id) <- socket.assigns.editing_id,
         transaction <- Financial.get_transaction_for_user!(editing_id, socket.assigns.user_id),
         {:ok, _transaction} <- Financial.update_transaction(transaction, params) do
      transactions = Financial.list_by_category(socket.assigns.user_id, socket.assigns.category_name)
      category_total = Enum.reduce(transactions, Decimal.new(0), &Decimal.add(&1.amount, &2))

      {:noreply,
       socket
       |> assign(
         transactions: transactions,
         category_total: category_total,
         transaction_count: length(transactions),
         editing_id: nil,
         edit_form: nil
       )
       |> put_flash(:info, gettext("Transaction updated successfully."))}
    else
      nil ->
        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, edit_form: to_form(changeset, as: :transaction))}
    end
  end

  @impl true
  def handle_event("confirm_delete", %{"id" => id}, socket) do
    {:noreply, assign(socket, confirm_delete_id: id)}
  end

  @impl true
  def handle_event("cancel_delete", _params, socket) do
    {:noreply, assign(socket, confirm_delete_id: nil)}
  end

  @impl true
  def handle_event("delete_transaction", %{"id" => id}, socket) do
    transaction = Financial.get_transaction_for_user!(id, socket.assigns.user_id)

    case Financial.delete_transaction(transaction) do
      {:ok, _transaction} ->
        transactions = Financial.list_by_category(socket.assigns.user_id, socket.assigns.category_name)
        category_total = Enum.reduce(transactions, Decimal.new(0), &Decimal.add(&1.amount, &2))

        {:noreply,
         socket
         |> assign(
           transactions: transactions,
           category_total: category_total,
           transaction_count: length(transactions),
           confirm_delete_id: nil
         )
         |> put_flash(:info, gettext("Transaction deleted successfully."))}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> assign(confirm_delete_id: nil)
         |> put_flash(:error, gettext("Failed to delete transaction."))}
    end
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

  defp build_category_cards(categories, summary_list, type) do
    summary_map = Map.new(summary_list, &{&1.name, &1})

    categories
    |> Enum.filter(&(&1.type == type))
    |> Enum.map(fn category ->
      summary = Map.get(summary_map, category.name)

      %{
        name: category.name,
        label: category.label,
        type: category.type,
        total: if(summary, do: summary.total, else: Decimal.new(0)),
        count: if(summary, do: summary.count, else: 0)
      }
    end)
  end

  def category_label(name) do
    case name do
      "food" -> gettext("Food & Dining")
      "transport" -> gettext("Transportation")
      "housing" -> gettext("Housing")
      "health" -> gettext("Health")
      "education" -> gettext("Education")
      "entertainment" -> gettext("Entertainment")
      "shopping" -> gettext("Shopping")
      "travel" -> gettext("Travel")
      "utilities" -> gettext("Utilities")
      "subscriptions" -> gettext("Subscriptions")
      "salary" -> gettext("Salary")
      "freelance" -> gettext("Freelance")
      "investments" -> gettext("Investments")
      "other" -> gettext("Other")
      _ -> name
    end
  end

  def categories_for_type(all_categories, type) do
    all_categories
    |> Enum.filter(&(&1.type == type))
    |> Enum.map(&{category_label(&1.name), &1.name})
  end
end
