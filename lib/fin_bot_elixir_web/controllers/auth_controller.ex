defmodule FinBotElixirWeb.AuthController do
  require Logger
  use FinBotElixirWeb, :controller
  alias FinBotElixir.Accounts

  # O usuário clica aqui (ex: /auth/google?token=FIN-A123)
  def request(conn, %{"provider" => "google"} = params) do
    # Guardamos o token na sessão para usar no callback
    conn = if params["token"], do: put_session(conn, :linking_token, params["token"]), else: conn

    config = google_config()

    case Assent.Strategy.Google.authorize_url(config) do
      {:ok, %{url: url, session_params: session_params}} ->
        conn
        |> put_session(:google_session_params, session_params)
        |> redirect(external: url)

      {:error, _reason} ->
        conn
        |> put_flash(:error, "Erro ao iniciar o login com Google.")
        |> redirect(to: ~p"/")
    end
  end

  # O Google volta para cá
  def callback(conn, %{"provider" => "google"} = params) do
    linking_token = get_session(conn, :linking_token)
    session_params = get_session(conn, :google_session_params)

    config =
      google_config()
      |> Keyword.put(:session_params, session_params)

    case Assent.Strategy.Google.callback(config, params) do
      {:ok, %{user: user_data}} ->
        case Accounts.register_or_link_google_user(user_data, linking_token) do
          {:ok, user} ->
            conn
            # Loga o usuário
            |> configure_session(renew: true)
            |> put_session(:user_id, user.id)
            |> delete_session(:linking_token)
            |> delete_session(:google_session_params)
            |> redirect(to: ~p"/dashboard")

          {:error, _changeset} ->
            conn
            |> delete_session(:linking_token)
            |> delete_session(:google_session_params)
            |> put_flash(:error, "Erro ao logar.")
            |> redirect(to: ~p"/")
        end

      {:error, reason} ->
        Logger.error("Google callback error: #{inspect(reason)}")
        conn
        |> delete_session(:linking_token)
        |> delete_session(:google_session_params)
        |> put_flash(:error, "Erro ao autenticar com Google.")
        |> redirect(to: ~p"/")
    end
  end

  defp google_config do
    base_config = Application.fetch_env!(:fin_bot_elixir, :google_auth)
    Keyword.put(base_config, :redirect_uri, url(~p"/auth/google/callback"))
  end
end
