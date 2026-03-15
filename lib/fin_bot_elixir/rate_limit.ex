defmodule FinBotElixir.RateLimit do
  @moduledoc """
  Rate limiter for the Developer API, backed by ETS via Hammer.
  """
  use Hammer, backend: :ets
end
