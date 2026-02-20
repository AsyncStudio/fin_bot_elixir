#!/bin/bash

mix deps.get

# Build assets
mix assets.setup

mix tailwind.install --if-missing
mix esbuild.install --if-missing
mix assets.deploy

# Run
mix phx.digest
mix phx.server
