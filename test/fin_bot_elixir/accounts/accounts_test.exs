defmodule FinBotElixir.AccountsTest do

  use FinBotElixir.DataCase

  describe "account creation" do
    test "creating a user assings a api key" do
      {:ok, user} = FinBotElixir.Accounts.create_user(%{
        full_name: "Usuario Teste",
        whatsapp_number: "5511888888888",
        linking_token: "TEST-123"
      })
      assert user.api_key != nil
    end
  end
end
