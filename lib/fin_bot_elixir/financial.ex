defmodule FinBotElixir.Financial do
  @moduledoc """
  The Financial context.
  """

  import Ecto.Query, warn: false
  alias FinBotElixir.Repo

  alias FinBotElixir.Financial.Transaction
  alias FinBotElixir.Financial.Tag
  alias FinBotElixir.Financial.Category

  @default_categories [
    %{name: "food", label: "Food & Dining", type: "expense"},
    %{name: "transport", label: "Transportation", type: "expense"},
    %{name: "housing", label: "Housing", type: "expense"},
    %{name: "health", label: "Health", type: "expense"},
    %{name: "education", label: "Education", type: "expense"},
    %{name: "entertainment", label: "Entertainment", type: "expense"},
    %{name: "shopping", label: "Shopping", type: "expense"},
    %{name: "travel", label: "Travel", type: "expense"},
    %{name: "utilities", label: "Utilities", type: "expense"},
    %{name: "subscriptions", label: "Subscriptions", type: "expense"},
    %{name: "salary", label: "Salary", type: "income"},
    %{name: "freelance", label: "Freelance", type: "income"},
    %{name: "investments", label: "Investments", type: "income"},
    %{name: "other", label: "Other", type: "expense"}
  ]

  @doc """
  Creates all default categories for a new user.
  """
  def create_default_categories(user_id) do
    Enum.each(@default_categories, fn cat ->
      %Category{}
      |> Category.changeset(Map.put(cat, :user_id, user_id))
      |> Repo.insert(on_conflict: :nothing)
    end)
  end

  @doc """
  Returns the list of categories for a user.
  """
  def list_categories_for_user(user_id) do
    from(c in Category,
      where: c.user_id == ^user_id,
      order_by: [asc: c.type, asc: c.name]
    )
    |> Repo.all()
  end

  @doc """
  Gets a single category belonging to the given user.
  Raises `Ecto.NoResultsError` if not found.
  """
  def get_category_for_user!(id, user_id) do
    Repo.get_by!(Category, id: id, user_id: user_id)
  end

  @doc """
  Updates a category's label and/or monthly_limit.
  """
  def update_category(%Category{} = category, attrs) do
    category
    |> Category.update_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking category changes.
  """
  def change_category(%Category{} = category, attrs \\ %{}) do
    Category.update_changeset(category, attrs)
  end

  @doc """
  Deletes a category.
  """
  def delete_category(%Category{} = category) do
    Repo.delete(category)
  end

  # Agrupa gastos por categoria para a tela inicial
  def list_category_usage(user_id) do
    query =
      from t in Transaction,
        where: t.user_id == ^user_id,
        group_by: t.category,
        select: %{
          name: t.category,
          total:
            sum(
              fragment("CASE WHEN ? = 'expense' THEN -? ELSE ? END", t.type, t.amount, t.amount)
            ),
          count: count(t.id)
        }

    Repo.all(query)
  end

  @doc """
  Groups categories by type (expense/income) and sums their totals for a given month and year.
  Returns a map with :expense_categories, :income_categories, :total_income, :total_expenses, :net_balance.
  """
  def dashboard_summary(user_id, month, year) do
    {start_dt, end_dt} = month_range(month, year)

    categories =
      from(t in Transaction,
        where:
          t.user_id == ^user_id and t.inserted_at >= ^start_dt and t.inserted_at <= ^end_dt,
        group_by: [t.category, t.type],
        select: %{
          name: t.category,
          type: t.type,
          total: sum(t.amount),
          count: count(t.id)
        }
      )
      |> Repo.all()

    expense_categories =
      categories
      |> Enum.filter(&(&1.type == "expense"))
      |> Enum.sort_by(& &1.total, :desc)

    income_categories =
      categories
      |> Enum.filter(&(&1.type == "income"))
      |> Enum.sort_by(& &1.total, :desc)

    total_expenses =
      expense_categories
      |> Enum.reduce(Decimal.new(0), &Decimal.add(&1.total, &2))

    total_income =
      income_categories
      |> Enum.reduce(Decimal.new(0), &Decimal.add(&1.total, &2))

    net_balance = Decimal.sub(total_income, total_expenses)

    %{
      expense_categories: expense_categories,
      income_categories: income_categories,
      total_expenses: total_expenses,
      total_income: total_income,
      net_balance: net_balance
    }
  end

  # Lista os detalhes de uma categoria específica para um mês e ano
  def list_by_category(user_id, category_name, month, year) do
    {start_dt, end_dt} = month_range(month, year)

    query =
      from t in Transaction,
        where:
          t.user_id == ^user_id and t.category == ^category_name and
            t.inserted_at >= ^start_dt and t.inserted_at <= ^end_dt,
        order_by: [desc: t.inserted_at],
        preload: [:tags]

    Repo.all(query)
  end

  @doc """
  Returns the list of transactions.

  ## Examples

      iex> list_transactions()
      [%Transaction{}, ...]

  """
  def list_transactions do
    Repo.all(Transaction)
  end

  @doc """
  Returns the list of transactions for a specific user.

  ## Examples

      iex> list_user_transactions(user_id)
      [%Transaction{}, ...]

  """
  def list_user_transactions(user_id) do
    Transaction
    |> where([t], t.user_id == ^user_id)
    |> order_by([t], desc: t.inserted_at)
    |> Repo.all()
  end

  def count_user_transactions(user_id) do
    Transaction
    |> where([t], t.user_id == ^user_id)
    |> select([t], count(t.id))
    |> Repo.one()
  end

  @doc """
  Gets a single transaction.

  Raises `Ecto.NoResultsError` if the Transaction does not exist.

  ## Examples

      iex> get_transaction!(123)
      %Transaction{}

      iex> get_transaction!(456)
      ** (Ecto.NoResultsError)

  """
  def get_transaction!(id), do: Repo.get!(Transaction, id)

  def get_transaction_for_user!(id, user_id) do
    Repo.get_by!(Transaction, id: id, user_id: user_id)
  end

  @doc """
  Creates a transaction.

  ## Examples

      iex> create_transaction(%{field: value})
      {:ok, %Transaction{}}

      iex> create_transaction(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_transaction(attrs \\ %{}) do
    %Transaction{}
    |> Transaction.changeset(attrs)
    |> Repo.insert()
    |> maybe_preload_tags()
  end

  def create_transaction_for_user(user_id, attrs \\ %{}) do
    attrs = Map.put(attrs, "user_id", user_id)

    %Transaction{}
    |> Transaction.changeset(attrs)
    |> Repo.insert()
    |> maybe_preload_tags()
  end

  def create_transaction_for_ui(user_id, attrs \\ %{}) do
    attrs = Map.put(attrs, "user_id", user_id)

    %Transaction{}
    |> Transaction.ui_changeset(attrs)
    |> Repo.insert()
    |> maybe_preload_tags()
  end

  def change_transaction_for_ui(%Transaction{} = transaction, attrs \\ %{}) do
    Transaction.ui_changeset(transaction, attrs)
  end

  @doc """
  Updates a transaction.

  ## Examples

      iex> update_transaction(transaction, %{field: new_value})
      {:ok, %Transaction{}}

      iex> update_transaction(transaction, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_transaction(%Transaction{} = transaction, attrs) do
    transaction
    |> Transaction.changeset(attrs)
    |> Repo.update()
    |> maybe_preload_tags()
  end

  @doc """
  Deletes a transaction.

  ## Examples

      iex> delete_transaction(transaction)
      {:ok, %Transaction{}}

      iex> delete_transaction(transaction)
      {:error, %Ecto.Changeset{}}

  """
  def delete_transaction(%Transaction{} = transaction) do
    Repo.delete(transaction)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking transaction changes.

  ## Examples

      iex> change_transaction(transaction)
      %Ecto.Changeset{data: %Transaction{}}

  """
  def change_transaction(%Transaction{} = transaction, attrs \\ %{}) do
    Transaction.changeset(transaction, attrs)
  end

  @doc """
  Returns all unique tag names used in transactions belonging to the given user.
  """
  def list_all_tag_names_for_user(user_id) do
    from(tag in Tag,
      join: tt in "transaction_tags", on: tt.tag_id == tag.id,
      join: t in Transaction, on: t.id == tt.transaction_id,
      where: t.user_id == ^user_id,
      select: tag.name,
      distinct: true,
      order_by: tag.name
    )
    |> Repo.all()
  end

  @doc """
  Adds a tag (by name) to a transaction. Creates the tag if it does not exist.
  """
  def add_tag_to_transaction(%Transaction{} = transaction, tag_name) do
    tag_name = String.trim(tag_name)

    tag =
      case Repo.insert(Tag.changeset(%Tag{}, %{name: tag_name}),
             on_conflict: :nothing,
             conflict_target: :name
           ) do
        {:ok, %Tag{id: nil}} -> Repo.get_by!(Tag, name: tag_name)
        {:ok, tag} -> tag
        {:error, _} -> Repo.get_by!(Tag, name: tag_name)
      end

    transaction = Repo.preload(transaction, :tags)

    if Enum.any?(transaction.tags, &(&1.name == tag_name)) do
      {:ok, transaction}
    else
      transaction
      |> Ecto.Changeset.change()
      |> Ecto.Changeset.put_assoc(:tags, [tag | transaction.tags])
      |> Repo.update()
    end
  end

  @doc """
  Removes a tag (by name) from a transaction.
  """
  def remove_tag_from_transaction(%Transaction{} = transaction, tag_name) do
    transaction = Repo.preload(transaction, :tags)
    new_tags = Enum.reject(transaction.tags, &(&1.name == tag_name))

    transaction
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.put_assoc(:tags, new_tags)
    |> Repo.update()
  end

  defp month_range(month, year) do
    days_in_month = Calendar.ISO.days_in_month(year, month)
    start_dt = NaiveDateTime.new!(year, month, 1, 0, 0, 0)
    end_dt = NaiveDateTime.new!(year, month, days_in_month, 23, 59, 59, {999_999, 6})
    {start_dt, end_dt}
  end

  defp maybe_preload_tags({:ok, %Transaction{} = transaction}) do
    {:ok, Repo.preload(transaction, :tags)}
  end

  defp maybe_preload_tags(result), do: result
end
