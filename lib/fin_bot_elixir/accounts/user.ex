defmodule FinBotElixir.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "users" do
    field :full_name, :string
    field :whatsapp_number, :string
    field :linking_token, :string
    field :firebase_uid, :string
    field :email, :string
    field :google_id, :string
    field :api_key, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(user, attrs) do
    user
      |> cast(attrs, [
        :full_name,
        :whatsapp_number,
        :linking_token,
        :firebase_uid,
        :email,
        :google_id,
        :api_key
      ])
      |> put_api_key()
      |> validate_required([:full_name])
      |> unique_constraint(:firebase_uid)
      |> unique_constraint(:linking_token)
      |> unique_constraint(:whatsapp_number)
      |> unique_constraint(:api_key)
  end

  defp put_api_key(changeset) do
    case get_field(changeset, :api_key) do
      nil -> put_change(changeset, :api_key, Ecto.UUID.generate() |> String.replace("-", ""))
      _ -> changeset
    end
  end
end
