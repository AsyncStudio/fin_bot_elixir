defmodule FinBotElixir.Repo do
  use Ecto.Repo,
    otp_app: :fin_bot_elixir,
    adapter: Ecto.Adapters.Postgres
end
