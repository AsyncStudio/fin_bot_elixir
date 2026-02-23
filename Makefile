
run:
	ENV_FILE=.env.dev iex -S mix phx.server

compose:
	docker-compose up

migrate:
	ENV_FILE=.env.dev mix ecto.migrate

