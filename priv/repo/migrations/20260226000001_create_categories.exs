defmodule FinBotElixir.Repo.Migrations.CreateCategories do
  use Ecto.Migration

  def change do
    create table(:categories, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :label, :string, null: false
      add :type, :string, null: false
      add :monthly_limit, :decimal

      add :user_id,
          references(:users, type: :binary_id, on_delete: :delete_all),
          null: false

      timestamps(type: :utc_datetime)
    end

    create index(:categories, [:user_id])
    create unique_index(:categories, [:user_id, :name])
  end
end
