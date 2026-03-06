defmodule FinBotElixir.Financial do
  @moduledoc """
  The Financial context.
  """
  require Logger

  import Ecto.Query, warn: false
  alias FinBotElixir.Repo

  alias FinBotElixir.Financial.Transaction
  alias FinBotElixir.Financial.Tag

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
        where: t.user_id == ^user_id and t.inserted_at >= ^start_dt and t.inserted_at <= ^end_dt,
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
  Returns the total amount for a specific category and type in the last 7 days for a user.
  Returns a Decimal (0 if no transactions found).
  """
  def weekly_category_total(user_id, category, type) do
    week_ago = NaiveDateTime.add(NaiveDateTime.utc_now(), -7, :day)

    from(t in Transaction,
      where:
        t.user_id == ^user_id and
          t.category == ^category and
          t.type == ^type and
          t.inserted_at >= ^week_ago,
      select: sum(t.amount)
    )
    |> Repo.one()
    |> case do
      nil -> Decimal.new(0)
      total -> total
    end
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

  # ============================================================================
  # TAG CRUD OPERATIONS
  # ============================================================================

  def list_tags_all() do
    Repo.all(Tag)
  end

  @doc """
  Returns the list of tags for a given user.

  ## Examples

      iex> list_tags(user_id)
      [%Tag{}, ...]

  """
  def list_tags(user_id) do
    from(tag in Tag,
      where: tag.user_id == ^user_id,
      order_by: [asc: tag.name]
    )
    |> Repo.all()
  end

  @doc """
  Gets a single tag by id and user_id.

  ## Examples

      iex> get_tag(tag_id, user_id)
      %Tag{}

      iex> get_tag(non_existent_id, user_id)
      nil

  """
  def get_tag(tag_id, user_id) do
    Repo.get_by(Tag, id: tag_id, user_id: user_id)
  end

  @doc """
  Creates a tag for a user.

  ## Examples

      iex> create_tag(user_id, %{name: "work"})
      {:ok, %Tag{}}

      iex> create_tag(user_id, %{name: ""})
      {:error, %Ecto.Changeset{}}

  """
  def create_tag(user_id, attrs \\ %{}) do
    %Tag{}
    |> Tag.changeset(Map.put(attrs, "user_id", user_id))
    |> Repo.insert()
  end

  @doc """
  Updates a tag.

  ## Examples

      iex> update_tag(tag, %{name: "new_name"})
      {:ok, %Tag{}}

      iex> update_tag(tag, %{name: ""})
      {:error, %Ecto.Changeset{}}

  """
  def update_tag(%Tag{} = tag, attrs) do
    tag
    |> Tag.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a tag.

  ## Examples

      iex> delete_tag(tag)
      {:ok, %Tag{}}

      iex> delete_tag(tag)
      {:error, %Ecto.Changeset{}}

  """
  def delete_tag(%Tag{} = tag) do
    Repo.delete(tag)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking tag changes.

  ## Examples

      iex> change_tag(tag)
      %Ecto.Changeset{data: %Tag{}}

  """
  def change_tag(%Tag{} = tag, attrs \\ %{}) do
    Tag.changeset(tag, attrs)
  end

  @doc """
  Returns all unique tag names used in transactions belonging to the given user.
  """
  def list_all_tag_names_for_user(user_id) do
    from(tag in Tag,
      join: tt in "transaction_tags",
      on: tt.tag_id == tag.id,
      join: t in Transaction,
      on: t.id == tt.transaction_id,
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
      Repo.insert(
        Tag.changeset(%Tag{}, %{name: tag_name, user_id: transaction.user_id}),
        on_conflict: :nothing,
        conflict_target: [:user_id, :name]
      )

    # tag = Repo.get_by!(Tag, user_id: transaction.user_id, name: tag_name)

    transaction = Repo.preload(transaction, :tags)
    Logger.debug("Associando tag \n'#{inspect(tag)}'\n\n à transação \n#{inspect(transaction)}")

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

  @doc """
  Executes a raw SQL SELECT query safely and returns the results as a list of maps.
  Only SELECT queries are allowed; any other statement type is rejected with `{:error, :not_select}`.
  """
  def execute_raw_query(sql) do
    trimmed = String.trim(sql)

    # Strip SQL block comments (/* ... */) and line comments (-- ...) before validation
    sanitized =
      trimmed
      |> String.replace(~r/\/\*.*?\*\//s, "")
      |> String.replace(~r/--[^\n]*/, "")
      |> String.trim()

    first_word = sanitized |> String.upcase() |> String.split() |> Enum.at(0, "")
    has_semicolon = String.contains?(sanitized, ";")

    cond do
      first_word != "SELECT" ->
        Logger.warning("execute_raw_query: rejecting non-SELECT query")
        {:error, :not_select}

      has_semicolon ->
        Logger.warning("execute_raw_query: rejecting query with semicolon (multiple statements)")
        {:error, :multiple_statements}

      true ->
        case Ecto.Adapters.SQL.query(Repo, sanitized, []) do
          {:ok, result} ->
            rows =
              Enum.map(result.rows, fn row ->
                result.columns
                |> Enum.zip(row)
                |> Map.new()
              end)

            {:ok, rows}

          {:error, reason} ->
            Logger.error("execute_raw_query: erro ao executar SQL: #{inspect(reason)}")
            {:error, reason}
        end
    end
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
