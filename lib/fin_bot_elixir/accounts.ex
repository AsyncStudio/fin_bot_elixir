defmodule FinBotElixir.Accounts do
  alias FinBotElixir.Repo
  alias FinBotElixir.Accounts.User

  def find_or_create_by_whatsapp(whatsapp_number) do
    case Repo.get_by(User, whatsapp_number: whatsapp_number) do
      %User{} = user ->
        {:ok, user}

      nil ->
        # If it doesn't exist, we create a "Shadow" user
        create_user(%{
          whatsapp_number: whatsapp_number,
          full_name: "Usuário #{whatsapp_number}",
          linking_token: generate_unique_token()
        })
    end
  end

  def create_user(attrs) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end

  def get_user(id), do: Repo.get(User, id)

  def get_user_by_api_key(api_key), do: Repo.get_by(User, api_key: api_key)

  def register_or_link_google_user(google_user_data, linking_token \\ nil) do
    email = google_user_data["email"]

    # 1. Try to find by email (in case already logged in before)
    # 2. If there is a token, try to find the Shadow User and update
    # 3. If not, create a new user from scratch
    case Repo.get_by(User, email: email) do
      %User{} = user ->
        {:ok, user}

      nil ->
        find_and_update_shadow_user(linking_token, google_user_data)
    end
  end

  defp find_and_update_shadow_user(nil, data), do: create_user_from_google(data)

  defp find_and_update_shadow_user(token, data) do
    case Repo.get_by(User, linking_token: token) do
      nil ->
        create_user_from_google(data)

      %User{} = user ->
        user
        |> User.changeset(%{
          email: data["email"],
          google_id: data["sub"],
          full_name: data["name"]
        })
        |> Repo.update()
    end
  end

  defp create_user_from_google(data) do
    create_user(%{
      email: data["email"],
      google_id: data["sub"],
      full_name: data["name"],
      # User who started from the Dashboard, not from WhatsApp
      whatsapp_number: nil
    })
  end

  defp generate_unique_token do
    # Generates a short and easy-to-type token, like "FIN-A123"
    "FIN-" <>
      (8 |> :crypto.strong_rand_bytes() |> Base.encode32(padding: false) |> binary_part(0, 4))
  end

  def build_linking_url(user) do
    host =
      Application.fetch_env!(:fin_bot_elixir, FinBotElixirWeb.Endpoint)[:host] ||
        "http://localhost:4000"

    "#{host}/auth/google?token=#{user.linking_token}"
  end
end
