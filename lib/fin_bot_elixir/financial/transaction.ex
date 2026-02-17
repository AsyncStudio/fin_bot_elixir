defmodule FinBotElixir.Financial.Transaction do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "transactions" do
    field :amount, :decimal
    field :description, :string
    field :category, :string
    field :type, :string # can be "expense" or "income"
    field :raw_input, :string
    field :user_id, :binary_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(transaction, attrs) do
    transaction
    |> cast(attrs, [:amount, :description, :category, :type, :raw_input, :user_id])
    |> validate_required([:amount, :description, :category, :type, :raw_input])
  end
end
