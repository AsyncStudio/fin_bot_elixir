defmodule FinBotElixirWeb.Api.V1.TagControllerTest do
  use FinBotElixirWeb.ConnCase, async: true

  alias FinBotElixir.Accounts
  alias FinBotElixir.Financial

  setup do
    {:ok, user} =
      Accounts.create_user(%{
        full_name: "Test User",
        whatsapp_number: "+5511888888888"
      })

    {:ok, user: user}
  end

  describe "GET /api/v1/tags/summary" do
    test "returns 401 without API key", %{conn: conn} do
      conn = get(conn, "/api/v1/tags/summary")
      assert json_response(conn, 401)
    end

    test "returns tag spending summary for authenticated user", %{conn: conn, user: user} do
      {:ok, transaction} =
        Financial.create_transaction_for_user(user.id, %{
          "amount" => "30.00",
          "description" => "Supermarket",
          "category" => "food",
          "type" => "expense"
        })

      Financial.add_tag_to_transaction(transaction, "groceries")

      conn =
        conn
        |> put_req_header("x-api-key", user.api_key)
        |> get("/api/v1/tags/summary")

      response = json_response(conn, 200)
      assert is_list(response["data"])

      [item | _] = response["data"]
      assert item["tag"] == "groceries"
      assert item["count"] == 1
    end

    test "returns empty summary when user has no tagged expenses", %{conn: conn, user: user} do
      conn =
        conn
        |> put_req_header("x-api-key", user.api_key)
        |> get("/api/v1/tags/summary")

      response = json_response(conn, 200)
      assert response["data"] == []
    end
  end
end
