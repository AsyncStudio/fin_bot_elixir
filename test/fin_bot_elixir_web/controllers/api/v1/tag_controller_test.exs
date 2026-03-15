defmodule FinBotElixirWeb.Api.V1.TagControllerTest do
  use FinBotElixirWeb.ConnCase, async: true

  alias FinBotElixir.AccountFixtures
  alias FinBotElixir.TagFixtures

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    test "fails when not authenticated", %{conn: conn} do
      conn = get(conn, Routes.tag_path(conn, :index))
      assert response(conn, 401)
    end

    test "lists all tags", %{conn: conn} do
      %{user1: user1} = AccountFixtures.user_fixture()
      tags = TagFixtures.tags_for_user(user1.id, ["tag1", "tag2"])

      conn = conn
        |> put_req_header("x-api-key", user1.api_key)
        |> get(Routes.tag_path(conn, :index))

      assert Enum.count(json_response(conn, 200)["data"]) == Enum.count(tags)
    end

    test "lists only user tags", %{conn: conn} do
      %{user1: user1} = AccountFixtures.user_fixture()
      tags = TagFixtures.tags_for_user(user1.id, ["tag1", "tag2"])

      TagFixtures.new_tag()

      conn = conn
        |> put_req_header("x-api-key", user1.api_key)
        |> get(Routes.tag_path(conn, :index))

      assert Enum.count(json_response(conn, 200)["data"]) == Enum.count(tags)
    end
  end
end
