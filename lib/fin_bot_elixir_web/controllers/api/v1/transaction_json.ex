defmodule FinBotElixirWeb.Api.V1.TransactionJSON do
  alias FinBotElixir.Financial.Transaction

  def index(%{transactions: transactions, page: page, page_size: page_size, total: total}) do
    %{
      data: Enum.map(transactions, &data/1),
      pagination: %{
        page: page,
        page_size: page_size,
        total: total
      }
    }
  end

  def show(%{transaction: transaction}) do
    %{data: data(transaction)}
  end

  defp data(%Transaction{} = transaction) do
    %{
      amount: transaction.amount,
      description: transaction.description,
      category: transaction.category,
      type: transaction.type,
      tags: render_tags(transaction.tags),
      inserted_at: transaction.inserted_at
    }
  end

  defp render_tags(%Ecto.Association.NotLoaded{}), do: []

  defp render_tags(tags) when is_list(tags) do
    Enum.map(tags, & &1.name)
  end
end
