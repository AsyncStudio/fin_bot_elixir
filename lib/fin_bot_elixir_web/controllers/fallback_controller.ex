defmodule FinBotElixirWeb.FallbackController do
  use FinBotElixirWeb, :controller

  alias Ecto.Changeset

  @doc """
  Handles action results that return `{:error, reason}` tuples.
  """
  def call(conn, {:error, %Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{errors: format_changeset_errors(changeset)})
  end

  def call(conn, {:error, reason}) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: format_reason(reason)})
  end

  defp format_changeset_errors(%Changeset{} = changeset) do
    Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end

  defp format_reason(reason) when is_binary(reason), do: reason

  defp format_reason(reason) when is_atom(reason) do
    reason
    |> Atom.to_string()
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  defp format_reason(_reason), do: "An unexpected error occurred"
end
