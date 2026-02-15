defmodule FinBot.Repo do
  use Ecto.Repo,
    otp_app: :fin_bot,
    adapter: Ecto.Adapters.Postgres
end
