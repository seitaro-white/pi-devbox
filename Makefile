.PHONY: build replace up versions

# Compose reads file selection, image/storage overrides and credentials from .env.
# No local configuration is required for the default Pi-only setup.

# Build from committed dependency inputs; Docker derives the runtime files.
build:
	docker compose build pi-box

versions:
	node scripts/check-versions.mjs

replace:
	docker compose up -d --no-build --pull never --no-deps --force-recreate --wait --wait-timeout 60 pi-box

up: build
	docker compose up -d --no-build --pull missing --wait --wait-timeout 60
