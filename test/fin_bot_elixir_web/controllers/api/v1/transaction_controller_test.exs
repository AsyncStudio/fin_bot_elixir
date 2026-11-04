defmodule FinBotElixirWeb.Api.V1.TransactionControllerTest do
  use FinBotElixirWeb.ConnCase, async: true

  alias FinBotElixir.AccountFixtures
  alias FinBotElixir.TransactionFixtures

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    test "fails when not authenticated", %{conn: conn} do
      conn = get(conn, Routes.transaction_path(conn, :index))
      assert response(conn, 401)
    end

    test "lists all transactions", %{conn: conn} do
      %{user1: user1} = AccountFixtures.user_fixture()
      transactions = TransactionFixtures.transaction_for_user(user1.id, [10, 20])

      conn = conn
        |> put_req_header("x-api-key", user1.api_key)
        |> get(Routes.transaction_path(conn, :index))

      assert Enum.count(json_response(conn, 200)["data"]) == Enum.count(transactions)
    end

    test "lists only user transactions", %{conn: conn} do
      %{user1: user1} = AccountFixtures.user_fixture()
      transactions = TransactionFixtures.transaction_for_user(user1.id, [10, 20])

      TransactionFixtures.new_transaction()

      conn = conn
        |> put_req_header("x-api-key", user1.api_key)
        |> get(Routes.transaction_path(conn, :index))

      assert Enum.count(json_response(conn, 200)["data"]) == Enum.count(transactions)
    end
  end
end
