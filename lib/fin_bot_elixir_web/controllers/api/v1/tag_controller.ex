defmodule FinBotElixirWeb.Api.V1.TagController do
  use FinBotElixirWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias FinBotElixir.Financial
  alias FinBotElixirWeb.Api.V1.Schemas

  action_fallback FinBotElixirWeb.FallbackController

  tags ["Tags"]

  security [%{"ApiKey" => []}]

  operation :summary,
    summary: "Tag spending summary",
    description:
      "Returns a summary of expenses grouped by tags assigned by Gemini AI, ordered by total amount.",
    responses: [
      ok: {"Tag summary", "application/json", Schemas.TagSummary},
      unauthorized: {"Unauthorized", "application/json", Schemas.ErrorResponse},
      too_many_requests: {"Rate limit exceeded", "application/json", Schemas.ErrorResponse}
    ]

  def summary(conn, _params) do
    user = conn.assigns.current_user
    summary = Financial.tags_summary_for_user(user.id)
    render(conn, :summary, summary: summary)
  end
end
