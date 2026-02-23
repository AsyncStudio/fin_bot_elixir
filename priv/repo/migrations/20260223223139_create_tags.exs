defmodule FinBotElixir.Repo.Migrations.CreateTags do
  use Ecto.Migration

  def change do
    create table(:tags, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:tags, [:name])

    create table(:transaction_tags, primary_key: false) do
      add :transaction_id,
          references(:transactions, type: :binary_id, on_delete: :delete_all),
          null: false

      add :tag_id, references(:tags, type: :binary_id, on_delete: :delete_all), null: false
    end

    create unique_index(:transaction_tags, [:transaction_id, :tag_id])
    create index(:transaction_tags, [:tag_id])
  end
end
