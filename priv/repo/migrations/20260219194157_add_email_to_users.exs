defmodule FinBotElixir.Repo.Migrations.AddEmailToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :email, :string
      # Para guardar o 'sub' do Google
      add :google_id, :string
    end

    create unique_index(:users, [:email])
  end
end
