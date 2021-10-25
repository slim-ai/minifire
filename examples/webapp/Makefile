.PHONY: build test minify build-backend build-frontend build-database build-test run dev

build: build-backend build-frontend build-database build-test

build-backend:
	@docker build --file extra/Dockerfile.backend  --tag webapp:backend  --network host .

build-frontend:
	@docker build --file extra/Dockerfile.frontend --tag webapp:frontend --network host .

build-database:
	@docker build --file extra/Dockerfile.database --tag webapp:database --network host .

build-test:
	@docker build --file extra/Dockerfile.test     --tag webapp:test     --network host .

test:
	@bash extra/test.sh

minify:
	@bash extra/minify.sh

run:
	@bash extra/run.sh

dev:
	@bash extra/dev.sh
