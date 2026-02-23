defmodule FinBotElixirWeb.AuthHTML do
  @moduledoc """
  This module contains pages rendered by AuthController.

  See the `auth_html` directory for all templates available.
  """
  use FinBotElixirWeb, :html

  embed_templates "auth_html/*"
end
