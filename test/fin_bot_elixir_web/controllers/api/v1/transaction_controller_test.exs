defmodule FinBotElixirWeb.Api.V1.TransactionControllerTest do
  use FinBotElixirWeb.ConnCase, async: true

  alias FinBotElixir.Accounts
  alias FinBotElixir.Financial

  setup do
    {:ok, user} =
      Accounts.create_user(%{
        full_name: "Test User",
        whatsapp_number: "+5511999999999"
      })

    {:ok, user: user}
  end

  describe "GET /api/v1/transactions" do
    test "returns 401 when no API key is provided", %{conn: conn} do
      conn = get(conn, "/api/v1/transactions")
      assert json_response(conn, 401)["error"] =~ "Missing x-api-key"
    end

    test "returns 401 when an invalid API key is provided", %{conn: conn} do
      conn =
        conn
        |> put_req_header("x-api-key", "invalid_key")
        |> get("/api/v1/transactions")

      assert json_response(conn, 401)["error"] =~ "Invalid API key"
    end

    test "returns paginated transactions for authenticated user", %{conn: conn, user: user} do
      {:ok, _} =
        Financial.create_transaction_for_user(user.id, %{
          "amount" => "50.00",
          "description" => "Grocery shopping",
          "category" => "food",
          "type" => "expense"
        })

      conn =
        conn
        |> put_req_header("x-api-key", user.api_key)
        |> get("/api/v1/transactions")

      response = json_response(conn, 200)
      assert is_list(response["data"])
      assert response["pagination"]["page"] == 1
      assert response["pagination"]["total"] == 1
    end

    test "supports page and page_size params", %{conn: conn, user: user} do
      conn =
        conn
        |> put_req_header("x-api-key", user.api_key)
        |> get("/api/v1/transactions?page=1&page_size=5")

      response = json_response(conn, 200)
      assert response["pagination"]["page"] == 1
      assert response["pagination"]["page_size"] == 5
    end
  end

  describe "GET /api/v1/transactions/:id" do
    test "returns 401 without API key", %{conn: conn} do
      conn = get(conn, "/api/v1/transactions/some-id")
      assert json_response(conn, 401)
    end

    test "returns 404 for non-existent transaction", %{conn: conn, user: user} do
      conn =
        conn
        |> put_req_header("x-api-key", user.api_key)
        |> get("/api/v1/transactions/00000000-0000-0000-0000-000000000000")

      assert json_response(conn, 404)["error"] == "Transaction not found"
    end

    test "returns transaction details for authenticated user", %{conn: conn, user: user} do
      {:ok, transaction} =
        Financial.create_transaction_for_user(user.id, %{
          "amount" => "42.50",
          "description" => "Coffee",
          "category" => "food",
          "type" => "expense"
        })

      conn =
        conn
        |> put_req_header("x-api-key", user.api_key)
        |> get("/api/v1/transactions/#{transaction.id}")

      response = json_response(conn, 200)
      assert response["data"]["description"] == "Coffee"
      assert response["data"]["category"] == "food"
      refute Map.has_key?(response["data"], "user_id")
      refute Map.has_key?(response["data"], "raw_input")
    end
  end
end
