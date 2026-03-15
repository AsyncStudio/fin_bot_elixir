defmodule FinBotElixirWeb.Api.V1.TagController do
  use FinBotElixirWeb, :controller

  alias FinBotElixir.Financial
  alias FinBotElixir.Financial.Tag

  action_fallback FinBotElixirWeb.FallbackController

  @doc """
  List all tags for the authenticated user.
  """
  def index(conn, _params) do
    tags = Financial.list_tags_all()
    render(conn, :index, tags: tags)
  end

  @doc """
  Create a new tag for the authenticated user.
  """
  def create(conn, %{"tag" => tag_params}) do
    user_id = conn.assigns[:current_scope][:id]

    if user_id do
      with {:ok, %Tag{} = tag} <- Financial.create_tag(user_id, tag_params) do
        conn
        |> put_status(:created)
        |> put_resp_header("location", ~p"/api/tags/#{tag.id}")
        |> render(:show, tag: tag)
      end
    else
      conn
      |> put_status(:unauthorized)
      |> put_view(FinBotElixirWeb.ErrorJSON)
      |> render(:error, %{reason: "Unauthorized"})
    end
  end

  @doc """
  Get a specific tag by ID for the authenticated user.
  """
  def show(conn, %{"id" => id}) do
    user_id = conn.assigns[:current_scope][:id]

    if user_id do
      case Financial.get_tag(id, user_id) do
        %Tag{} = tag ->
          render(conn, :show, tag: tag)

        nil ->
          conn
          |> put_status(:not_found)
          |> put_view(FinBotElixirWeb.ErrorJSON)
          |> render(:error, %{reason: "Tag not found"})
      end
    else
      conn
      |> put_status(:unauthorized)
      |> put_view(FinBotElixirWeb.ErrorJSON)
      |> render(:error, %{reason: "Unauthorized"})
    end
  end

  @doc """
  Update a tag for the authenticated user.
  """
  def update(conn, %{"id" => id, "tag" => tag_params}) do
    user_id = conn.assigns[:current_scope][:id]

    if user_id do
      case Financial.get_tag(id, user_id) do
        %Tag{} = tag ->
          with {:ok, %Tag{} = updated_tag} <- Financial.update_tag(tag, tag_params) do
            render(conn, :show, tag: updated_tag)
          end

        nil ->
          conn
          |> put_status(:not_found)
          |> put_view(FinBotElixirWeb.ErrorJSON)
          |> render(:error, %{reason: "Tag not found"})
      end
    else
      conn
      |> put_status(:unauthorized)
      |> put_view(FinBotElixirWeb.ErrorJSON)
      |> render(:error, %{reason: "Unauthorized"})
    end
  end

  @doc """
  Delete a tag for the authenticated user.
  """
  def delete(conn, %{"id" => id}) do
    user_id = conn.assigns[:current_scope][:id]

    if user_id do
      case Financial.get_tag(id, user_id) do
        %Tag{} = tag ->
          with {:ok, %Tag{}} <- Financial.delete_tag(tag) do
            send_resp(conn, :no_content, "")
          end

        nil ->
          conn
          |> put_status(:not_found)
          |> put_view(FinBotElixirWeb.ErrorJSON)
          |> render(:error, %{reason: "Tag not found"})
      end
    else
      conn
      |> put_status(:unauthorized)
      |> put_view(FinBotElixirWeb.ErrorJSON)
      |> render(:error, %{reason: "Unauthorized"})
    end
  end
end
