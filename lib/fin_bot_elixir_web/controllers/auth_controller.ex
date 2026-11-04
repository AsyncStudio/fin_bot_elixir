defmodule FinBotElixirWeb.AuthController do
  require Logger
  use FinBotElixirWeb, :controller
  alias FinBotElixir.Accounts

  @doc """
    Entry route for authentication.
    > Redirects to dashboard if already logged in.
    > Starts OAuth flow for login or linking if parameters indicate.
    > Shows default login screen if no specific parameter is provided.
  """
  def request(conn, %{"provider" => "google"} = params) do
    current_user = conn.assigns[:current_user]

    if current_user do
      redirect(conn, to: ~p"/dashboard")
    else
      cond do

        params["token"] ->
          # Has linking token > starts OAuth to link account (e.g.: /auth/google?token=FIN-A123)
          conn
          |> put_session(:linking_token, params["token"])
          |> start_google_oauth()


        params["login"] == "true" ->
          # "Sign-In with Google" button was clicked > starts OAuth for login
          start_google_oauth(conn)


        true ->
          # No token and no login indicator > shows login screen
          current_scope = %{user: current_user}
          render(conn, :login, current_scope: current_scope)
      end
    end
  end

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
            # Logs in the user
            |> configure_session(renew: true)
            |> put_session(:user_id, user.id)
            |> delete_session(:linking_token)
            |> delete_session(:google_session_params)
            |> redirect(to: ~p"/dashboard")

          {:error, _changeset} ->
            conn
            |> delete_session(:linking_token)
            |> delete_session(:google_session_params)
            |> put_flash(:error, "Error logging in.")
            |> redirect(to: ~p"/")
        end

      {:error, reason} ->
        Logger.error("Google callback error: #{inspect(reason)}")

        conn
        |> delete_session(:linking_token)
        |> delete_session(:google_session_params)
        |> put_flash(:error, "Error authenticating with Google.")
        |> redirect(to: ~p"/")
    end
  end

  def logout(conn, _params) do
    conn
    |> configure_session(drop: true)
    |> redirect(to: ~p"/")
  end

  defp start_google_oauth(conn) do
    config = google_config()

    case Assent.Strategy.Google.authorize_url(config) do
      {:ok, %{url: url, session_params: session_params}} ->
        conn
        |> put_session(:google_session_params, session_params)
        |> redirect(external: url)

      {:error, _reason} ->
        conn
        |> put_flash(:error, "Error starting login with Google.")
        |> redirect(to: ~p"/")
    end
  end

  defp google_config do
    base_config = Application.fetch_env!(:fin_bot_elixir, :google_auth)
    Keyword.put(base_config, :redirect_uri, url(~p"/auth/google/callback"))
  end
end
