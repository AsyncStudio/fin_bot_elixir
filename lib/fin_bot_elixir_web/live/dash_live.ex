defmodule FinBotElixirWeb.DashLive do
  use FinBotElixirWeb, :live_view
  alias FinBotElixir.Financial

  @impl true
  def mount(_params, session, socket) do
    user_id = session["user_id"]
    {:ok, assign(socket, user_id: user_id)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  # Lógica para a tela de LISTA
  defp apply_action(socket, :index, _params) do
    categories = Financial.list_category_usage(socket.assigns.user_id)
    assign(socket, page_title: "FinBot - Categorias", categories: categories)
  end

  # Lógica para a tela de EXTRATO
  defp apply_action(socket, :show, %{"name" => name}) do
    transactions = Financial.list_by_category(socket.assigns.user_id, name)

    assign(socket,
      page_title: "Extrato: #{name}",
      category_name: name,
      transactions: transactions
    )
  end
end
