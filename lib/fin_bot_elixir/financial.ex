defmodule FinBotElixir.Financial do
  @moduledoc """
  The Financial context.
  """

  import Ecto.Query, warn: false
  alias FinBotElixir.Repo

  alias FinBotElixir.Financial.Transaction

  # Agrupa gastos por categoria para a tela inicial
  def list_category_usage(user_id) do
    query = from t in Transaction,
      where: t.user_id == ^user_id,
      group_by: t.category,
      select: %{name: t.category, total: sum(fragment("CASE WHEN ? = 'expense' THEN -? ELSE ? END", t.type, t.amount, t.amount)), count: count(t.id)}

    Repo.all(query)
  end

  # Lista os detalhes de uma categoria específica
  def list_by_category(user_id, category_name) do
    query = from t in Transaction,
      where: t.user_id == ^user_id and t.category == ^category_name,
      order_by: [desc: t.inserted_at]

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
  end

  def create_transaction_for_user(user_id, attrs \\ %{}) do
    attrs = Map.put(attrs, "user_id", user_id)

    %Transaction{}
    |> Transaction.changeset(attrs)
    |> Repo.insert()
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
end
