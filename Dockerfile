# Build stage
FROM elixir:1.16-alpine AS builder

# Install Node.js for building assets
RUN apk add --no-cache nodejs npm git build-base

# Set working directory
WORKDIR /app

# Copy mix files
COPY mix.exs mix.lock ./

# Install Hex and Rebar
RUN mix local.hex --force && mix local.rebar --force

# Install dependencies
RUN MIX_ENV=prod mix deps.get --only prod

# Copy application code
COPY lib lib
COPY config config
COPY priv priv
COPY assets assets
COPY .env.prod .env.prod

# Compile code
RUN MIX_ENV=prod mix compile

# Build assets
RUN MIX_ENV=prod mix assets.deploy

# Create release
RUN MIX_ENV=prod mix release

# Runtime stage
FROM alpine:3.18

# Install runtime dependencies
RUN apk add --no-cache openssl bash ca-certificates libstdc++

# Set working directory
WORKDIR /app

# Copy release from builder
COPY --from=builder /app/_build/prod/rel/fin_bot_elixir ./

# Create a non-root user
RUN addgroup -g 1000 app && adduser -u 1000 -G app -s /bin/sh -D app
USER app

# Expose port
EXPOSE 4000

# Environment variables
ENV PHX_SERVER=true
ENV MIX_ENV=prod

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD bin/fin_bot_elixir eval "FinBotElixir.Repo.query!('SELECT 1')" || exit 1

# Start command
CMD ["ENV_FILE=.env.prod", "bin/fin_bot_elixir", "start"]
