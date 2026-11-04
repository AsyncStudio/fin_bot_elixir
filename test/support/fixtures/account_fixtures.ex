defmodule FinBotElixir.AccountFixtures do

  alias FinBotElixir.Accounts

  @default_user_attrs %{
    full_name: "Usuario Teste",
    whatsapp_number: "5511888888888",
    linking_token: "USER-TESTE"
  }

  def user_fixture() do
    {:ok, user1} = Accounts.create_user(%{
      full_name: "Usuario 1",
      whatsapp_number: "5511777777777",
      linking_token: "USER-ABC"
    })

    {:ok, user1} = Accounts.create_user(%{
      full_name: "Usuario 2",
      whatsapp_number: "5511999999999",
      linking_token: "USER-XYZ"
    })

    %{user1: user1}
  end

  def new_user(attrs \\ %{}) do
    {:ok, user} = attrs
      |> Enum.into(@default_user_attrs)
      |> Accounts.create_user()
    user
  end
end
