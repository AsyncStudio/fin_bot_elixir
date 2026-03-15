defmodule FinBotElixirWeb.Router do
  use FinBotElixirWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {FinBotElixirWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    # Sempre tenta carregar o usuário se ele existir na sessão
    plug FinBotElixirWeb.AuthPlug, :fetch_current_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :api_v1 do
    plug :accepts, ["json"]
    plug OpenApiSpex.Plug.PutApiSpec, module: FinBotElixirWeb.ApiSpec
    plug FinBotElixirWeb.Plugs.AuthenticateApiKey
    plug FinBotElixirWeb.Plugs.RateLimiter
  end

  pipeline :api_docs do
    plug :accepts, ["html", "json"]
    plug OpenApiSpex.Plug.PutApiSpec, module: FinBotElixirWeb.ApiSpec
  end

  pipeline :require_authenticated_user do
    plug FinBotElixirWeb.AuthPlug, :require_authenticated_user
  end

  scope "/", FinBotElixirWeb do
    pipe_through :browser

    get "/", PageController, :home
    get "/auth/:provider", AuthController, :request
    get "/auth/:provider/callback", AuthController, :callback
    get "/logout", AuthController, :logout
  end

  # Rotas Protegidas (Dashboard do FinBot)
  scope "/dashboard", FinBotElixirWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :authenticated,
      on_mount: [{FinBotElixirWeb.Live.UserAuth, :require_authenticated_user}] do
      live "/", DashLive, :index
      live "/:name", DashLive, :show
    end
  end

  scope "/api", FinBotElixirWeb do
    pipe_through :api

    get "/webhook/whatsapp", WhatsappController, :verify
    post "/webhook/whatsapp", WhatsappController, :receive

    resources "/transactions", TransactionController, except: [:new, :edit]
    resources "/tags", TagController, except: [:new, :edit]
  end

  # Developer API v1 – authenticated & rate-limited
  scope "/api/v1", FinBotElixirWeb.Api.V1 do
    pipe_through :api_v1

    get "/transactions", TransactionController, :index
    get "/transactions/:id", TransactionController, :show
    get "/tags/summary", TagController, :summary
  end

  # API documentation (public, no auth required)
  scope "/api" do
    pipe_through :api_docs

    get "/docs", OpenApiSpex.Plug.SwaggerUI, path: "/api/openapi.json"
    get "/openapi.json", OpenApiSpex.Plug.RenderSpec, []
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:fin_bot_elixir, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: FinBotElixirWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
