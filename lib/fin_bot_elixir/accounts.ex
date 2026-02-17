defmodule FinBotElixir.Accounts do
  alias FinBotElixir.Repo
  alias FinBotElixir.Accounts.User

  def find_or_create_by_whatsapp(whatsapp_number) do
    case Repo.get_by(User, whatsapp_number: whatsapp_number) do
      %User{} = user ->
        {:ok, user}

      nil ->
        # Se não existe, criamos um usuário "Sombra"
        %User{}
        |> User.changeset(%{
          whatsapp_number: whatsapp_number,
          linking_token: generate_unique_token(),
          full_name: "Novo Usuário" # Nome temporário
        })
        |> Repo.insert()
    end
  end

  defp generate_unique_token do
    # Gera um token curto e fácil de digitar, tipo "FIN-A123"
    "FIN-" <> (8 |> :crypto.strong_rand_bytes() |> Base.encode32(padding: false) |> binary_part(0, 4))
  end
end
