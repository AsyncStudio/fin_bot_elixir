defmodule FinBotElixir.Repo.Migrations.AddApiKeyToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :api_key, :string
    end

    # Backfill existing users with placeholder keys using available SQL functions.
    # These keys have sufficient entropy for initial setup. In production deployments,
    # existing users should regenerate their API keys via the application after this migration.
    execute(
      "UPDATE users SET api_key = md5(random()::text || clock_timestamp()::text || id::text) || md5(random()::text) WHERE api_key IS NULL",
      "SELECT 1"
    )

    alter table(:users) do
      modify :api_key, :string, null: false
    end

    create unique_index(:users, [:api_key])
  end
end
