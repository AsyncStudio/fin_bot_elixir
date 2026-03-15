defmodule FinBotElixirWeb.Plugs.RateLimiter do
  @moduledoc """
  Rate limiting plug for the Developer API.

  Limits each API key to 60 requests per minute. Returns 429 when exceeded.
  """
  import Plug.Conn
  import Phoenix.Controller

  require Logger

  @limit 60
  @window_ms :timer.minutes(1)

  def init(opts), do: opts

  def call(conn, _opts) do
    %{api_key: api_key} = conn.assigns.current_user

    case FinBotElixir.RateLimit.hit("api_v1:#{api_key}", @window_ms, @limit) do
      {:allow, _count} ->
        conn

      {:deny, _count} ->
        Logger.warning("Rate limit exceeded", api_key_prefix: String.slice(api_key, 0, 8))

        conn
        |> put_status(:too_many_requests)
        |> json(%{error: "Too Many Requests. Limit: #{@limit} requests per minute."})
        |> halt()
    end
  end
end
