# Docker Setup for fin_bot_elixir

This guide explains how to build and run the fin_bot_elixir Phoenix application using Docker.

## Quick Start

### 1. Prepare environment variables

Copy the example environment file and configure it:

```bash
cp .env.docker.example .env.docker
```

Edit `.env.docker` and set required values, especially:

- `SECRET_KEY_BASE`: Generate one with `mix phx.gen.secret`
- `GEMINI_API_KEY`: Your Gemini API key

### 2. Build and run with Docker Compose

```bash
docker-compose up --build
```

This will:

- Build the Docker image from the Dockerfile
- Start the PostgreSQL database
- Start the Phoenix application
- Run migrations automatically on startup

The application will be available at `http://localhost:4000`

### 3. Stop the application

```bash
docker-compose down
```

To also remove the database volume:

```bash
docker-compose down -v
```

## Building the Docker Image Manually

If you want to build just the image without Docker Compose:

```bash
docker build -t fin_bot_elixir:latest .
```

## Running the Container Directly

```bash
docker run \
  -p 4000:4000 \
  -e DATABASE_URL="postgresql://postgres:postgres@db:5432/fin_bot_elixir" \
  -e SECRET_KEY_BASE="your-secret-key-base" \
  -e GEMINI_API_KEY="your-api-key" \
  fin_bot_elixir:latest
```

## Environment Variables

Required environment variables:

| Variable          | Description                               | Example                                   |
| ----------------- | ----------------------------------------- | ----------------------------------------- |
| `DATABASE_URL`    | PostgreSQL connection string              | `postgresql://user:pass@host:5432/dbname` |
| `SECRET_KEY_BASE` | Phoenix secret key for session encryption | Generated via `mix phx.gen.secret`        |
| `PHX_HOST`        | Hostname for the Phoenix endpoint         | `localhost` or `example.com`              |
| `GEMINI_API_KEY`  | Google Gemini API key                     | Your API key                              |
| `PORT`            | Port to listen on                         | `4000`                                    |

Optional environment variables:

| Variable    | Description                          | Default |
| ----------- | ------------------------------------ | ------- |
| `POOL_SIZE` | Database connection pool size        | `10`    |
| `ECTO_IPV6` | Enable IPv6 for database connections | `false` |

## Development Workflow

For local development (not using Docker), use:

```bash
# Install dependencies and setup
mix setup

# Run tests
mix test

# Start development server
mix phx.server
```

## Docker Compose Profiles

The current setup includes two services:

- **db**: PostgreSQL 15.3 database
- **app**: Phoenix application

Both are started by default with `docker-compose up`.

## Troubleshooting

### Application can't connect to database

- Ensure the database is healthy: `docker-compose ps`
- Check logs: `docker-compose logs db app`
- Verify `DATABASE_URL` contains the correct hostname (should be `db` when using Docker Compose)

### Port already in use

Change the port mapping in `docker-compose.yml`:

```yaml
ports:
  - "4001:4000" # Maps container port 4000 to host port 4001
```

### Database connection refused

- Wait for the database to be ready (check healthcheck)
- Verify `POSTGRES_PASSWORD` matches `DATABASE_PASSWORD`
- Clear volumes and restart: `docker-compose down -v && docker-compose up`

### Application crashes on startup

- Check logs: `docker-compose logs app`
- Ensure `SECRET_KEY_BASE` is set and valid
- Verify all required environment variables are provided

## Production Considerations

The Dockerfile uses a multi-stage build to minimize image size:

1. **Builder stage**: Compiles code and builds assets
2. **Runtime stage**: Lightweight Alpine Linux with only runtime dependencies

### For production deployment:

1. Set `PHX_HOST` to your domain
2. Enable HTTPS (configure SSL certificates in config)
3. Use a strong `SECRET_KEY_BASE`
4. Use a managed database service instead of Docker
5. Set `POOL_SIZE` based on your database capacity
6. Configure appropriate resource limits

Example production environment:

```bash
PHX_HOST=example.com
DATABASE_URL=postgresql://prod_user:strong_password@db.example.com:5432/fin_bot_prod
SECRET_KEY_BASE=<generate-with-mix-phx.gen.secret>
POOL_SIZE=20
```

## Image Size

The multi-stage build keeps the final image lean:

- Builder stage: ~700MB (discarded after build)
- Runtime image: ~120-150MB
