defmodule FinBot.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :full_name, :string
      add :whatsapp_number, :string
      add :linking_token, :string
      add :firebase_uid, :string, null: true

      timestamps(type: :utc_datetime)
    end

    create unique_index(:users, [:firebase_uid])
    create unique_index(:users, [:linking_token])
    create unique_index(:users, [:whatsapp_number])
  end
end
