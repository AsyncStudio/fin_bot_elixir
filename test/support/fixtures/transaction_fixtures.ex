defmodule FinBotElixir.TransactionFixtures do

  alias FinBotElixir.Financial

  alias FinBotElixir.AccountFixtures

  @default_transaction_attrs %{
    "description" => "Test Transaction",
    "category" => "other",
    "type" => "expense",
    "raw_input" => "Test Transaction",
    "amount" => Decimal.new("10.00")
  }

  def new_transaction(attrs \\ %{}) do
    new_user = AccountFixtures.new_user()

    {:ok, transaction} =
      attrs
      |> Enum.into(@default_transaction_attrs)
      |> Map.put("user_id", new_user.id)
      |> Financial.create_transaction()

    transaction
  end

  def transaction_for_user(user_id, amount_list) do
    attrs_list = amount_list
      |> Enum.map(&map_transaction_with_amount(&1))
    attrs_list
      |> Enum.map(fn attrs ->
        Financial.create_transaction_for_user(user_id, attrs)
      end)
  end

  defp map_transaction_with_amount(amount) when is_float(amount) do
    @default_transaction_attrs
      |> Map.put("amount", Decimal.from_float(amount))
      |> Map.put("description", "Test Transaction of #{amount}")
  end

  defp map_transaction_with_amount(amount) do
    @default_transaction_attrs
      |> Map.put("amount", Decimal.new(amount))
      |> Map.put("description", "Test Transaction of #{amount}")
  end
end
