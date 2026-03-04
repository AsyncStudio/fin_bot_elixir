defmodule FinBotElixir.Repo.Migrations.BackfillDefaultCategoriesForUsersWithoutCategories do
  use Ecto.Migration

  import Ecto.Query

  def up do
    user_ids_without_categories =
      repo().all(
        from u in "users",
          left_join: c in "categories",
          on: c.user_id == u.id,
          group_by: u.id,
          having: count(c.id) == 0,
          select: u.id
      )

    now = DateTime.utc_now() |> DateTime.truncate(:second)

    entries =
      for user_id <- user_ids_without_categories,
          category <- default_categories() do
        %{
          id: Ecto.UUID.generate() |> to_uuid_binary(),
          user_id: to_uuid_binary(user_id),
          name: category.name,
          label: category.label,
          type: category.type,
          monthly_limit: nil,
          inserted_at: now,
          updated_at: now
        }
      end

    if entries != [] do
      repo().insert_all(
        "categories",
        entries,
        on_conflict: :nothing,
        conflict_target: [:user_id, :name]
      )
    end
  end

  def down do
    :ok
  end

  defp to_uuid_binary(<<_::128>> = uuid), do: uuid
  defp to_uuid_binary(uuid) when is_binary(uuid), do: Ecto.UUID.dump!(uuid)

  defp default_categories do
    [
      %{name: "food", label: "Food & Dining", type: "expense"},
      %{name: "transport", label: "Transportation", type: "expense"},
      %{name: "housing", label: "Housing", type: "expense"},
      %{name: "health", label: "Health", type: "expense"},
      %{name: "education", label: "Education", type: "expense"},
      %{name: "entertainment", label: "Entertainment", type: "expense"},
      %{name: "shopping", label: "Shopping", type: "expense"},
      %{name: "travel", label: "Travel", type: "expense"},
      %{name: "utilities", label: "Utilities", type: "expense"},
      %{name: "subscriptions", label: "Subscriptions", type: "expense"},
      %{name: "salary", label: "Salary", type: "income"},
      %{name: "freelance", label: "Freelance", type: "income"},
      %{name: "investments", label: "Investments", type: "income"},
      %{name: "other", label: "Other", type: "expense"}
    ]
  end
end
