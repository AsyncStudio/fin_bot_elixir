defmodule FinBotElixirWeb.PageController do
  use FinBotElixirWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
