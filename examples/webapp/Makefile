.PHONY: build test minify run dev

pull:
	docker compose --profile=all pull

build:
	docker compose --profile=all build

test:
	bash ../../scripts/test.sh

minify:
	bash ../../scripts/minify.sh

run:
	bash ../../scripts/run.sh
