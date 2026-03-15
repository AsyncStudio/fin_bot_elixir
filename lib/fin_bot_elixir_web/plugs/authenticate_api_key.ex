defmodule FinBotElixirWeb.Plugs.AuthenticateApiKey do
  @moduledoc """
  Plug that authenticates requests using the `x-api-key` header.

  Validates the key against the database and assigns the user to
  `conn.assigns.current_user`, or halts with 401 if invalid.
  """
  import Plug.Conn
  import Phoenix.Controller

  alias FinBotElixir.Accounts

  require Logger

  def init(opts), do: opts

  def call(conn, _opts) do
    case get_req_header(conn, "x-api-key") do
      [api_key | _] ->
        authenticate(conn, api_key)

      [] ->
        reject_unauthorized(conn, "Missing x-api-key header")
    end
  end

  defp authenticate(conn, api_key) do
    case Accounts.get_user_by_api_key(api_key) do
      nil ->
        reject_unauthorized(conn, "Invalid API key")

      user ->
        Logger.info("API access granted",
          api_key_prefix: String.slice(api_key, 0, 8),
          user_id: user.id
        )

        assign(conn, :current_user, user)
    end
  end

  defp reject_unauthorized(conn, reason) do
    conn
    |> put_status(:unauthorized)
    |> json(%{error: reason})
    |> halt()
  end
end
