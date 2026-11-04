defmodule FinBotElixir.Repo.Migrations.CreateApiKeyOnAccount do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :api_key, :string
    end

    create unique_index(:users, [:api_key])
  end
end
