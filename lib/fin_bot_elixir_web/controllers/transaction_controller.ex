defmodule FinBotElixirWeb.TransactionController do
  use FinBotElixirWeb, :controller

  alias FinBotElixir.Financial
  alias FinBotElixir.Financial.Transaction

  action_fallback FinBotElixirWeb.FallbackController

  def index(conn, _params) do
    transactions = Financial.list_transactions()
    render(conn, :index, transactions: transactions)
  end

  def create(conn, %{"transaction" => transaction_params}) do
    with {:ok, %Transaction{} = transaction} <- Financial.create_transaction(transaction_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/transactions/#{transaction}")
      |> render(:show, transaction: transaction)
    end
  end

  def show(conn, %{"id" => id}) do
    transaction = Financial.get_transaction!(id)
    render(conn, :show, transaction: transaction)
  end

  def update(conn, %{"id" => id, "transaction" => transaction_params}) do
    transaction = Financial.get_transaction!(id)

    with {:ok, %Transaction{} = transaction} <- Financial.update_transaction(transaction, transaction_params) do
      render(conn, :show, transaction: transaction)
    end
  end

  def delete(conn, %{"id" => id}) do
    transaction = Financial.get_transaction!(id)

    with {:ok, %Transaction{}} <- Financial.delete_transaction(transaction) do
      send_resp(conn, :no_content, "")
    end
  end
end
