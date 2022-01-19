.PHONY: pull test minify build

pull:
	@docker compose --profile=all pull

build:
	@docker compose --profile=all build

test:
	@bash extra/test.sh

minify:
	@bash extra/minify.sh
