defmodule FinBotElixir.TagFixtures do
  alias FinBotElixir.Financial
  alias FinBotElixir.AccountFixtures

  @default_tag_attrs %{
    "name" => "Test Tag",
  }

  def new_tag(attrs \\ %{}) do
    new_user = AccountFixtures.new_user()

    attrs = attrs |> Enum.into(@default_tag_attrs)

    {:ok, tag} = Financial.create_tag(new_user.id, attrs)
    tag
  end

  def tags_for_user(user_id, name_list) do
    attrs_list = name_list
      |> Enum.map(&map_tag_with_name(&1))
    attrs_list
      |> Enum.map(fn attrs ->
        Financial.create_tag(user_id, attrs)
      end)
  end

  defp map_tag_with_name(name) do
    @default_tag_attrs
      |> Map.put("name", name)
  end
end
