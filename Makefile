
run:
	ENV_FILE=.env.dev iex -S mix phx.server

migrate:
	ENV_FILE=.env.dev mix ecto.migrate

