defmodule FinBotElixirWeb.AuthPlug do
  import Plug.Conn
  import Phoenix.Controller
  alias FinBotElixir.Accounts

  def init(opts), do: opts

  def call(conn, action) when is_atom(action) do
    apply(__MODULE__, action, [conn, []])
  end

  def call(conn, {action, action_opts}) when is_atom(action) do
    apply(__MODULE__, action, [conn, action_opts])
  end

  def fetch_current_user(conn, _opts) do
    user_id = get_session(conn, :user_id)

    user = user_id && Accounts.get_user(user_id)
    assign(conn, :current_user, user)
  end

  def require_authenticated_user(conn, _opts) do
    if conn.assigns.current_user do
      conn
    else
      conn
      |> put_flash(:error, "Você precisa estar logado para acessar.")
      |> redirect(to: "/")
      |> halt()
    end
  end
end
