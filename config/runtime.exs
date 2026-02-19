import Config
import Dotenvy

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/fin_bot_elixir start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :fin_bot_elixir, FinBotElixirWeb.Endpoint, server: true
end

# region: Custom

env_file = System.get_env("ENV_FILE") || ".env.#{config_env()}"
IO.puts("Carregando variáveis de ambiente de #{Path.absname(env_file)}")

unless File.exists?(env_file) do
  raise """
  Environment file not found: #{Path.absname(env_file)}
  Please create the file or set the ENV_FILE environment variable.
  """
end

source!([
  Path.absname(env_file),
  System.get_env()
])

config :gemini_ex,
  api_key: env!("GEMINI_API_KEY", :string)

config :fin_bot_elixir, :google_auth,
  client_id: env!("GOOGLE_CLIENT_ID", :string),
  client_secret: env!("GOOGLE_CLIENT_SECRET", :string),
  strategy: Assent.Strategy.Google

config :fin_bot_elixir, :whatsapp,
  base_url: env!("FACEBOOK_API_URL", :string),
  token: env!("WHATSAPP_ACCESS_TOKEN", :string),
  phone_id: env!("WHATSAPP_PHONE_NUMBER_ID", :string)


# endregion

if config_env() == :prod do
  database_url =
    env!("DATABASE_URL", :string) ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :fin_bot_elixir, FinBotElixir.Repo,
    ssl: true,
    url: database_url,
    pool_size: String.to_integer(env!("POOL_SIZE", :string) || "10"),
    # For machines with several cores, consider starting multiple pools of `pool_size`
    # pool_count: 4,
    socket_options: maybe_ipv6

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    env!("SECRET_KEY_BASE", :string) ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = env!("PHX_HOST", :string) || "example.com"
  port = String.to_integer(env!("PORT", :string) || "4000")

  config :fin_bot_elixir, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :fin_bot_elixir, FinBotElixirWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/bandit/Bandit.html#t:options/0
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :fin_bot_elixir, FinBotElixirWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://hexdocs.pm/plug/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :fin_bot_elixir, FinBotElixirWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.

  # ## Configuring the mailer
  #
  # In production you need to configure the mailer to use a different adapter.
  # Here is an example configuration for Mailgun:
  #
  #     config :fin_bot_elixir, FinBotElixir.Mailer,
  #       adapter: Swoosh.Adapters.Mailgun,
  #       api_key: env("MAILGUN_API_KEY"),
  #       domain: env("MAILGUN_DOMAIN")
  #
  # Most non-SMTP adapters require an API client. Swoosh supports Req, Hackney,
  # and Finch out-of-the-box. This configuration is typically done at
  # compile-time in your config/prod.exs:
  #
  #     config :swoosh, :api_client, Swoosh.ApiClient.Req
  #
  # See https://hexdocs.pm/swoosh/Swoosh.html#module-installation for details.
end
