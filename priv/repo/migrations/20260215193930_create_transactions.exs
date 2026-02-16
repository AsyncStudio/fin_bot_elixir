defmodule FinBot.Repo.Migrations.CreateTransactions do
  use Ecto.Migration

  def change do
    create table(:transactions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :amount, :decimal
      add :description, :string
      add :category, :string
      add :type, :string
      add :raw_input, :text
      add :user_id, references(:users, on_delete: :nothing, type: :binary_id)

      timestamps(type: :utc_datetime)
    end

    create index(:transactions, [:user_id])
  end
end
