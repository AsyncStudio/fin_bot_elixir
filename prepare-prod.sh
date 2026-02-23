#!/bin/bash

mix deps.get

# Build assets
mix gettext.extract --merge
mix assets.setup

mix tailwind.install --if-missing
mix esbuild.install --if-missing
mix assets.deploy

mix phx.digest
