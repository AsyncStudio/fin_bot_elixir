defmodule FinBotElixirWeb.Api.V1.TransactionController do
  use FinBotElixirWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias FinBotElixir.Financial
  alias FinBotElixirWeb.Api.V1.Schemas

  action_fallback FinBotElixirWeb.FallbackController

  tags ["Transactions"]

  security [%{"ApiKey" => []}]

  operation :index,
    summary: "List transactions",
    description: "Returns a paginated list of transactions for the authenticated user.",
    parameters: [
      page: [
        in: :query,
        schema: %OpenApiSpex.Schema{type: :integer, minimum: 1, default: 1},
        description: "Page number (1-based)"
      ],
      page_size: [
        in: :query,
        schema: %OpenApiSpex.Schema{type: :integer, minimum: 1, maximum: 100, default: 20},
        description: "Number of items per page"
      ]
    ],
    responses: [
      ok: {"Transactions list", "application/json", Schemas.TransactionList},
      unauthorized: {"Unauthorized", "application/json", Schemas.ErrorResponse},
      too_many_requests: {"Rate limit exceeded", "application/json", Schemas.ErrorResponse}
    ]

  def index(conn, params) do
    user = conn.assigns.current_user
    page = parse_positive_integer(params["page"], 1)
    page_size = parse_positive_integer(params["page_size"], 20) |> min(100)

    transactions = Financial.list_user_transactions_paginated(user.id, page, page_size)
    total = Financial.count_user_transactions(user.id)

    render(conn, :index,
      transactions: transactions,
      page: page,
      page_size: page_size,
      total: total
    )
  end

  operation :show,
    summary: "Get transaction",
    description: "Returns a single transaction by ID for the authenticated user.",
    parameters: [
      id: [in: :path, schema: %OpenApiSpex.Schema{type: :string, format: :uuid}, required: true]
    ],
    responses: [
      ok: {"Transaction details", "application/json", Schemas.TransactionResponse},
      unauthorized: {"Unauthorized", "application/json", Schemas.ErrorResponse},
      not_found: {"Not found", "application/json", Schemas.ErrorResponse},
      too_many_requests: {"Rate limit exceeded", "application/json", Schemas.ErrorResponse}
    ]

  def show(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    case Financial.get_transaction_for_user_with_tags(id, user.id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Transaction not found"})

      transaction ->
        render(conn, :show, transaction: transaction)
    end
  end

  defp parse_positive_integer(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {n, ""} when n >= 1 -> n
      _ -> default
    end
  end

  defp parse_positive_integer(_, default), do: default
end
