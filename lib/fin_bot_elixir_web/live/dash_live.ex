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
    user_categories = Financial.list_categories_for_user(socket.assigns.user_id)

    expense_categories =
      build_category_cards(user_categories, summary.expense_categories, "expense")

    income_categories =
      build_category_cards(user_categories, summary.income_categories, "income")

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
      editing_id: nil,
      editing_category_id: nil,
      edit_category_form: nil,
      confirm_delete_category_id: nil
    )
  end

  # Lógica para a tela de EXTRATO
  defp apply_action(socket, :show, %{"name" => name}) do
    month = socket.assigns.filter_month
    year = socket.assigns.filter_year
    transactions = Financial.list_by_category(socket.assigns.user_id, name, month, year)
    user_categories = Financial.list_categories_for_user(socket.assigns.user_id)

    found_category = Enum.find(user_categories, &(&1.name == name))

    category_type = if found_category, do: found_category.type, else: "expense"
    category_display_label = if found_category, do: found_category.label, else: name

    category_total =
      Enum.reduce(transactions, Decimal.new(0), &Decimal.add(&1.amount, &2))

    month_label = month_year_label(month, year)

    socket
    |> assign(
      page_title: category_display_label,
      category_name: name,
      category_display_label: category_display_label,
      category_type: category_type,
      category_total: category_total,
      transaction_count: length(transactions),
      month_label: month_label,
      all_categories: user_categories,
      transactions: transactions,
      all_tags: Financial.list_all_tag_names_for_user(socket.assigns.user_id),
      editing_id: nil,
      edit_form: nil,
      confirm_delete_id: nil,
      show_add_modal: false,
      add_form: to_form(Financial.change_transaction_for_ui(%Transaction{}), as: :transaction)
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
         |> assign(
           transactions: [transaction | socket.assigns.transactions],
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

      # Replace the transaction in the list
      updated_transactions =
        Enum.map(socket.assigns.transactions, fn t ->
          if t.id == updated_transaction.id, do: updated_transaction, else: t
        end)

      {:noreply,
       socket
       |> assign(
         transactions: updated_transactions,
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
        updated_transactions = Enum.reject(socket.assigns.transactions, &(&1.id == transaction.id))

        {:noreply,
         socket
         |> assign(
           transactions: updated_transactions,
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
  def handle_event("add_tag", %{"transaction_id" => id, "tag_name" => tag_name}, socket) do
    tag_name = String.trim(tag_name)

    if tag_name == "" do
      {:noreply, socket}
    else
      transaction = Financial.get_transaction_for_user!(id, socket.assigns.user_id)

      case Financial.add_tag_to_transaction(transaction, tag_name) do
        {:ok, updated_transaction} ->
          updated_transactions =
            Enum.map(socket.assigns.transactions, fn t ->
              if t.id == id, do: updated_transaction, else: t
            end)

          all_tags =
            if tag_name in socket.assigns.all_tags do
              socket.assigns.all_tags
            else
              Financial.list_all_tag_names_for_user(socket.assigns.user_id)
            end

          {:noreply,
           socket
           |> assign(transactions: updated_transactions, all_tags: all_tags)
           |> push_event("reset_form", %{id: "add-tag-form-#{id}"})}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, gettext("Failed to add tag."))}
      end
    end
  end

  @impl true
  def handle_event("remove_tag", %{"transaction_id" => id, "tag_name" => tag_name}, socket) do
    transaction = Financial.get_transaction_for_user!(id, socket.assigns.user_id)

    case Financial.remove_tag_from_transaction(transaction, tag_name) do
      {:ok, updated_transaction} ->
        updated_transactions =
          Enum.map(socket.assigns.transactions, fn t ->
            if t.id == id, do: updated_transaction, else: t
          end)

        {:noreply, assign(socket, transactions: updated_transactions)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Failed to remove tag."))}
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

  @impl true
  def handle_event("open_edit_category", %{"id" => id}, socket) do
    category = Financial.get_category_for_user!(id, socket.assigns.user_id)
    form = to_form(Financial.change_category(category), as: :category)
    {:noreply, assign(socket, editing_category_id: id, edit_category_form: form)}
  end

  @impl true
  def handle_event("cancel_edit_category", _params, socket) do
    {:noreply, assign(socket, editing_category_id: nil, edit_category_form: nil)}
  end

  @impl true
  def handle_event("save_category", %{"category" => params}, socket) do
    with editing_id when not is_nil(editing_id) <- socket.assigns.editing_category_id,
         category <- Financial.get_category_for_user!(editing_id, socket.assigns.user_id),
         {:ok, _updated} <- Financial.update_category(category, params) do
      month = socket.assigns.filter_month
      year = socket.assigns.filter_year
      summary = Financial.dashboard_summary(socket.assigns.user_id, month, year)
      user_categories = Financial.list_categories_for_user(socket.assigns.user_id)

      expense_categories =
        build_category_cards(user_categories, summary.expense_categories, "expense")

      income_categories =
        build_category_cards(user_categories, summary.income_categories, "income")

      {:noreply,
       socket
       |> assign(
         expense_categories: expense_categories,
         income_categories: income_categories,
         editing_category_id: nil,
         edit_category_form: nil
       )
       |> put_flash(:info, gettext("Category updated successfully."))}
    else
      nil ->
        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, edit_category_form: to_form(changeset, as: :category))}
    end
  end

  @impl true
  def handle_event("confirm_delete_category", %{"id" => id}, socket) do
    {:noreply, assign(socket, confirm_delete_category_id: id)}
  end

  @impl true
  def handle_event("cancel_delete_category", _params, socket) do
    {:noreply, assign(socket, confirm_delete_category_id: nil)}
  end

  @impl true
  def handle_event("delete_category", %{"id" => id}, socket) do
    category = Financial.get_category_for_user!(id, socket.assigns.user_id)

    case Financial.delete_category(category) do
      {:ok, _} ->
        month = socket.assigns.filter_month
        year = socket.assigns.filter_year
        summary = Financial.dashboard_summary(socket.assigns.user_id, month, year)
        user_categories = Financial.list_categories_for_user(socket.assigns.user_id)

        expense_categories =
          build_category_cards(user_categories, summary.expense_categories, "expense")

        income_categories =
          build_category_cards(user_categories, summary.income_categories, "income")

        {:noreply,
         socket
         |> assign(
           expense_categories: expense_categories,
           income_categories: income_categories,
           confirm_delete_category_id: nil
         )
         |> put_flash(:info, gettext("Category deleted successfully."))}

      {:error, _} ->
        {:noreply,
         socket
         |> assign(confirm_delete_category_id: nil)
         |> put_flash(:error, gettext("Failed to delete category."))}
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
        id: category.id,
        name: category.name,
        label: category.label,
        type: category.type,
        monthly_limit: category.monthly_limit,
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
    |> Enum.map(&{&1.label, &1.name})
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

  @doc """
  Returns the limit usage percentage (0-100) for a category card.
  Returns nil if no monthly_limit is set.
  """
  def limit_percentage(%{monthly_limit: nil}), do: nil
  def limit_percentage(%{monthly_limit: limit, total: total}) do
    if Decimal.compare(limit, 0) == :gt do
      pct =
        total
        |> Decimal.div(limit)
        |> Decimal.mult(100)
        |> Decimal.round(0)
        |> Decimal.to_integer()

      min(pct, 100)
    else
      nil
    end
  end
end
