defmodule FinBotElixirWeb.Live.UserAuth do
  @moduledoc """
  LiveView on_mount hook that loads the current user from the session.
  """
  import Phoenix.Component

  alias FinBotElixir.Accounts

  def on_mount(:require_authenticated_user, _params, session, socket) do
    user_id = session["user_id"]
    user = user_id && Accounts.get_user(user_id)

    if user do
      {:cont,
       socket
       |> assign(:current_user, user)
       |> assign(:current_scope, %{user: user})}
    else
      {:halt,
       socket
       |> Phoenix.LiveView.put_flash(:error, "Você precisa estar logado para acessar o Dash.")
       |> Phoenix.LiveView.redirect(to: "/")}
    end
  end

  def on_mount(:fetch_current_user, _params, session, socket) do
    user_id = session["user_id"]
    user = user_id && Accounts.get_user(user_id)

    {:cont,
     socket
     |> assign(:current_user, user)
     |> assign(:current_scope, if(user, do: %{user: user}, else: nil))}
  end
end
