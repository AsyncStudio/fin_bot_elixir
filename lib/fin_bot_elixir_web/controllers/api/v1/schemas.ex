defmodule FinBotElixirWeb.Api.V1.Schemas do
  @moduledoc """
  OpenApiSpex schemas for the Developer API v1.
  """

  alias OpenApiSpex.Schema

  defmodule Tag do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Tag",
      description: "A transaction tag",
      type: :object,
      properties: %{
        name: %Schema{type: :string, description: "Tag name", example: "groceries"}
      },
      required: [:name]
    })
  end

  defmodule Transaction do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Transaction",
      description: "A financial transaction",
      type: :object,
      properties: %{
        amount: %Schema{
          type: :string,
          description: "Transaction amount as decimal string",
          example: "42.50"
        },
        description: %Schema{
          type: :string,
          description: "Transaction description",
          example: "Lunch at the restaurant"
        },
        category: %Schema{
          type: :string,
          description: "Transaction category",
          example: "food"
        },
        type: %Schema{
          type: :string,
          enum: ["expense", "income"],
          description: "Transaction type",
          example: "expense"
        },
        tags: %Schema{
          type: :array,
          items: %Schema{type: :string},
          description: "Tags assigned by Gemini AI",
          example: ["#restaurant", "#lunch"]
        },
        inserted_at: %Schema{
          type: :string,
          format: :"date-time",
          description: "Transaction creation timestamp"
        }
      },
      required: [:amount, :description, :category, :type, :inserted_at]
    })
  end

  defmodule TransactionList do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "TransactionList",
      description: "A paginated list of transactions",
      type: :object,
      properties: %{
        data: %Schema{
          type: :array,
          items: FinBotElixirWeb.Api.V1.Schemas.Transaction
        },
        pagination: %Schema{
          type: :object,
          properties: %{
            page: %Schema{type: :integer, example: 1},
            page_size: %Schema{type: :integer, example: 20},
            total: %Schema{type: :integer, example: 100}
          }
        }
      },
      required: [:data, :pagination]
    })
  end

  defmodule TagSummaryItem do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "TagSummaryItem",
      description: "Spending summary for a single tag",
      type: :object,
      properties: %{
        tag: %Schema{type: :string, description: "Tag name", example: "#groceries"},
        total: %Schema{
          type: :string,
          description: "Total amount spent on this tag",
          example: "150.00"
        },
        count: %Schema{type: :integer, description: "Number of transactions", example: 5}
      },
      required: [:tag, :total, :count]
    })
  end

  defmodule TransactionResponse do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "TransactionResponse",
      description: "A single transaction response",
      type: :object,
      properties: %{
        data: FinBotElixirWeb.Api.V1.Schemas.Transaction
      },
      required: [:data]
    })
  end

  defmodule TagSummary do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "TagSummary",
      description: "Spending summary grouped by tags",
      type: :object,
      properties: %{
        data: %Schema{
          type: :array,
          items: FinBotElixirWeb.Api.V1.Schemas.TagSummaryItem
        }
      },
      required: [:data]
    })
  end

  defmodule ErrorResponse do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "ErrorResponse",
      description: "An error response",
      type: :object,
      properties: %{
        error: %Schema{type: :string, description: "Error message"}
      },
      required: [:error]
    })
  end
end
