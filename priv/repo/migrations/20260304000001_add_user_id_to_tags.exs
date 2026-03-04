defmodule FinBotElixir.Repo.Migrations.AddUserIdToTags do
  use Ecto.Migration

  def change do
    # Delete all existing tags before adding user_id column
    do
      execute "DELETE FROM tags"
    rescue
      _ -> :ok
    end

    alter table(:tags) do
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
    end

    # Drop the old unique index on name alone
    drop_if_exists unique_index(:tags, [:name])

    # Create a new unique index on (user_id, name) to allow same tag names across different users
    create unique_index(:tags, [:user_id, :name])

    # Index for faster lookups by user_id
    create index(:tags, [:user_id])
  end
end
