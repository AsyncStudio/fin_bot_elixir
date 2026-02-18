defmodule FinBotElixirWeb.TransactionJSON do
  alias FinBotElixir.Financial.Transaction

  @doc """
  Renders a list of transactions.
  """
  def index(%{transactions: transactions}) do
    %{data: for(transaction <- transactions, do: data(transaction))}
  end

  @doc """
  Renders a single transaction.
  """
  def show(%{transaction: transaction}) do
    %{data: data(transaction)}
  end

  defp data(%Transaction{} = transaction) do
    %{
      id: transaction.id,
      amount: transaction.amount,
      description: transaction.description,
      category: transaction.category,
      type: transaction.type,
      raw_input: transaction.raw_input,
      user_id: transaction.user_id,
      inserted_at: transaction.inserted_at,
      updated_at: transaction.updated_at
    }
  end
end
