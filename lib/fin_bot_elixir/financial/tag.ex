defmodule FinBotElixir.Financial.Tag do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "tags" do
    field :name, :string
    belongs_to :user, FinBotElixir.Accounts.User

    many_to_many :transactions, FinBotElixir.Financial.Transaction,
      join_through: "transaction_tags"

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(tag, attrs) do
    tag
    |> cast(attrs, [:name, :user_id])
    |> validate_required([:name, :user_id])
    |> validate_length(:name, min: 1, max: 50)
    |> unique_constraint(:name, name: :tags_user_id_name_index)
  end
end
