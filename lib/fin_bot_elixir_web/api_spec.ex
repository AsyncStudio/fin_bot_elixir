defmodule FinBotElixirWeb.ApiSpec do
  @moduledoc """
  OpenAPI specification for the FinBot Developer API.
  """

  @behaviour OpenApiSpex.OpenApi

  alias OpenApiSpex.{Components, Info, OpenApi, Paths, SecurityScheme, Server}

  @impl OpenApi
  def spec do
    %OpenApi{
      info: %Info{
        title: "FinBot Developer API",
        version: "1.0.0",
        description: """
        The FinBot Developer API provides read-only access to your personal financial data,
        including transactions and tag-based spending summaries processed by Gemini AI.

        ## Authentication
        All endpoints require a valid API key passed in the `x-api-key` request header.

        ## Rate Limiting
        Requests are limited to 60 per minute per API key. Exceeding this limit returns `429 Too Many Requests`.
        """
      },
      servers: [
        %Server{url: "/", description: "Current server"}
      ],
      components: %Components{
        securitySchemes: %{
          "ApiKey" => %SecurityScheme{
            type: "apiKey",
            in: "header",
            name: "x-api-key",
            description: "API key obtained from your FinBot user profile"
          }
        }
      },
      paths: Paths.from_router(FinBotElixirWeb.Router)
    }
    |> OpenApiSpex.resolve_schema_modules()
  end
end
