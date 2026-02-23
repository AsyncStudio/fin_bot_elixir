defmodule FinBotElixirWeb.DashLive do
  use FinBotElixirWeb, :live_view
  alias FinBotElixir.Financial
  alias FinBotElixir.Financial.Transaction

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    now = Date.utc_today()

    {:ok,
     assign(socket,
       user_id: user.id,
       user_name: user.full_name,
       filter_month: now.month,
       filter_year: now.year
     )}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  # Lógica para a tela de LISTA (dashboard principal)
  defp apply_action(socket, :index, _params) do
    month = socket.assigns.filter_month
    year = socket.assigns.filter_year
    summary = Financial.dashboard_summary(socket.assigns.user_id, month, year)
    categories = Transaction.categories()

    expense_categories = build_category_cards(categories, summary.expense_categories, "expense")
    income_categories = build_category_cards(categories, summary.income_categories, "income")

    month_label = month_year_label(month, year)

    assign(socket,
      page_title: "Minhas Finanças",
      month_label: month_label,
      expense_categories: expense_categories,
      income_categories: income_categories,
      total_expenses: summary.total_expenses,
      total_income: summary.total_income,
      net_balance: summary.net_balance,
      confirm_delete_id: nil,
      show_add_modal: false,
      editing_id: nil
    )
  end

  # Lógica para a tela de EXTRATO
  defp apply_action(socket, :show, %{"name" => name}) do
    month = socket.assigns.filter_month
    year = socket.assigns.filter_year
    transactions = Financial.list_by_category(socket.assigns.user_id, name, month, year)
    all_categories = Transaction.categories()

    category_type =
      case all_categories |> Enum.find(&(&1.name == name)) do
        nil -> "expense"
        cat -> cat.type
      end

    category_total =
      Enum.reduce(transactions, Decimal.new(0), &Decimal.add(&1.amount, &2))

    month_label = month_year_label(month, year)

    socket
    |> assign(
      page_title: "#{name}",
      category_name: name,
      category_type: category_type,
      category_total: category_total,
      transaction_count: length(transactions),
      month_label: month_label,
      all_categories: all_categories,
      editing_id: nil,
      edit_form: nil,
      confirm_delete_id: nil,
      show_add_modal: false,
      add_form: to_form(Financial.change_transaction_for_ui(%Transaction{}), as: :transaction)
    )
    |> stream(:transactions, transactions, reset: true)
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
  def handle_event("open_add_modal", _params, socket) do
    add_form = to_form(Financial.change_transaction_for_ui(%Transaction{}), as: :transaction)
    {:noreply, assign(socket, show_add_modal: true, add_form: add_form)}
  end

  @impl true
  def handle_event("cancel_add", _params, socket) do
    {:noreply, assign(socket, show_add_modal: false)}
  end

  @impl true
  def handle_event("add_transaction", %{"transaction" => params}, socket) do
    params =
      Map.merge(params, %{
        "category" => socket.assigns.category_name,
        "type" => socket.assigns.category_type
      })

    case Financial.create_transaction_for_ui(socket.assigns.user_id, params) do
      {:ok, transaction} ->
        new_total = Decimal.add(socket.assigns.category_total, transaction.amount)

        {:noreply,
         socket
         |> stream(:transactions, [transaction])
         |> assign(
           category_total: new_total,
           transaction_count: socket.assigns.transaction_count + 1,
           show_add_modal: false,
           add_form: to_form(Financial.change_transaction_for_ui(%Transaction{}), as: :transaction)
         )
         |> put_flash(:info, gettext("Transaction created successfully."))}

      {:error, changeset} ->
        {:noreply, assign(socket, add_form: to_form(changeset, as: :transaction))}
    end
  end

  @impl true
  def handle_event("save_transaction", %{"transaction" => params}, socket) do
    with editing_id when not is_nil(editing_id) <- socket.assigns.editing_id,
         transaction <- Financial.get_transaction_for_user!(editing_id, socket.assigns.user_id),
         {:ok, updated_transaction} <- Financial.update_transaction(transaction, params) do
      # Calculate the difference to update total efficiently
      amount_diff = Decimal.sub(updated_transaction.amount, transaction.amount)
      new_total = Decimal.add(socket.assigns.category_total, amount_diff)

      {:noreply,
       socket
       |> stream(:transactions, [updated_transaction])
       |> assign(
         category_total: new_total,
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
        new_total = Decimal.sub(socket.assigns.category_total, transaction.amount)

        {:noreply,
         socket
         |> stream_delete(:transactions, transaction)
         |> assign(
           category_total: new_total,
           transaction_count: socket.assigns.transaction_count - 1,
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

  @impl true
  def handle_event("filter_date", %{"month" => month_str, "year" => year_str}, socket) do
    month = String.to_integer(month_str)

    year =
      case Integer.parse(year_str) do
        {y, ""} when y >= 1900 and y <= 2100 -> y
        _ -> socket.assigns.filter_year
      end

    socket = assign(socket, filter_month: month, filter_year: year)

    socket =
      case socket.assigns.live_action do
        :index -> apply_action(socket, :index, %{})
        :show -> apply_action(socket, :show, %{"name" => socket.assigns.category_name})
      end

    {:noreply, socket |> assign(confirm_delete_id: nil, show_add_modal: false, editing_id: nil)}
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

  def month_options do
    [
      {gettext("January"), 1},
      {gettext("February"), 2},
      {gettext("March"), 3},
      {gettext("April"), 4},
      {gettext("May"), 5},
      {gettext("June"), 6},
      {gettext("July"), 7},
      {gettext("August"), 8},
      {gettext("September"), 9},
      {gettext("October"), 10},
      {gettext("November"), 11},
      {gettext("December"), 12}
    ]
  end

  defp month_year_label(month, year) do
    {month_name, _} = Enum.find(month_options(), fn {_, m} -> m == month end)
    "#{month_name} #{year}"
  end
end
