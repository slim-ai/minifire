.PHONY: build test minify build-backend build-frontend build-database build-test run dev

build:
	docker compose --profile=all build

build-backend:
	docker compose --profile=all build backend

build-frontend:
	docker compose --profile=all build frontend

build-database:
	docker compose --profile=all build database

build-test:
	docker compose --profile=all build test

test:
	bash extra/test.sh

minify:
	bash extra/minify.sh
	suffix=-minified bash extra/test.sh

run:
	bash extra/run.sh

dev:
	bash extra/dev.sh
