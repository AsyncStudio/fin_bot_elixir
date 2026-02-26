defmodule FinBotElixir.Financial.Transaction do
  use Ecto.Schema
  import Ecto.Changeset

  @categories [
    %{name: "food", label: "Food & Dining", type: "expense"},
    %{name: "transport", label: "Transportation", type: "expense"},
    %{name: "housing", label: "Housing", type: "expense"},
    %{name: "health", label: "Health", type: "expense"},
    %{name: "education", label: "Education", type: "expense"},
    %{name: "entertainment", label: "Entertainment", type: "expense"},
    %{name: "shopping", label: "Shopping", type: "expense"},
    %{name: "travel", label: "Travel", type: "expense"},
    %{name: "utilities", label: "Utilities", type: "expense"},
    %{name: "subscriptions", label: "Subscriptions", type: "expense"},
    %{name: "salary", label: "Salary", type: "income"},
    %{name: "freelance", label: "Freelance", type: "income"},
    %{name: "investments", label: "Investments", type: "income"},
    %{name: "other", label: "Other", type: "expense"}
  ]

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "transactions" do
    field :amount, :decimal
    field :description, :string
    field :category, :string
    # can be "expense" or "income"
    field :type, :string
    field :raw_input, :string
    # field :user_id, :binary_id
    belongs_to :user, FinBotElixir.Accounts.User

    many_to_many :tags, FinBotElixir.Financial.Tag,
      join_through: "transaction_tags",
      on_replace: :delete

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(transaction, attrs) do
    transaction
    |> cast(attrs, [:amount, :description, :category, :type, :raw_input, :user_id])
    |> validate_required([:amount, :description, :category, :type, :raw_input])
    |> validate_inclusion(:category, category_values())
  end

  @doc false
  def ui_changeset(transaction, attrs) do
    transaction
    |> cast(attrs, [:amount, :description, :category, :type, :user_id])
    |> validate_required([:amount, :description, :category, :type])
    |> validate_change(:amount, fn :amount, value ->
      case Decimal.compare(value, Decimal.new(0)) do
        :gt -> []
        _ -> [amount: "must be greater than 0"]
      end
    end)
    |> validate_inclusion(:category, category_values())
  end

  def categories, do: @categories

  def category_values, do: Enum.map(@categories, & &1.name)
end
