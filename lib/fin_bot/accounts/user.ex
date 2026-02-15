defmodule FinBot.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :full_name, :string
    field :whatsapp_number, :string
    field :linking_token, :string
    field :firebase_uid, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:full_name, :whatsapp_number, :linking_token, :firebase_uid])
    |> validate_required([:full_name, :whatsapp_number, :linking_token, :firebase_uid])
    |> unique_constraint(:firebase_uid)
    |> unique_constraint(:linking_token)
    |> unique_constraint(:whatsapp_number)
  end
end
