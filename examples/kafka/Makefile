.PHONY: pull test minify build

pull:
	docker compose --profile=all pull

build:
	docker compose --profile=all build

test:
	bash ../../scripts/test.sh

minify:
	bash ../../scripts/minify.sh
