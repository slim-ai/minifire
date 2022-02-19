.PHONY: build test minify run dev

pull:
	docker compose --profile=all pull

build:
	docker compose --profile=all build

test:
	bash ../../extra/test.sh

minify:
	bash ../../extra/minify.sh

run:
	bash ../../extra/run.sh

dev:
	bash ../../extra/dev.sh
