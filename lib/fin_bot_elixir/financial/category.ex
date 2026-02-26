defmodule FinBotElixir.Financial.Category do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "categories" do
    field :name, :string
    field :label, :string
    field :type, :string
    field :monthly_limit, :decimal

    belongs_to :user, FinBotElixir.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(category, attrs) do
    category
    |> cast(attrs, [:name, :label, :type, :monthly_limit, :user_id])
    |> validate_required([:name, :label, :type, :user_id])
    |> validate_inclusion(:type, ["expense", "income"])
    |> unique_constraint([:user_id, :name])
  end

  @doc false
  def update_changeset(category, attrs) do
    category
    |> cast(attrs, [:label, :monthly_limit])
    |> validate_required([:label])
  end
end
