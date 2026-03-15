defmodule FinBotElixirWeb.Api.V1.TagJSON do
  def summary(%{summary: items}) do
    %{data: Enum.map(items, &summary_item/1)}
  end

  defp summary_item(%{tag: tag, total: total, count: count}) do
    %{
      tag: tag,
      total: total,
      count: count
    }
  end
end
