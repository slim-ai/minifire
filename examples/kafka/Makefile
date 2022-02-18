.PHONY: pull test minify build

pull:
	docker compose --profile=all pull

build:
	docker compose --profile=all build

test:
	bash extra/test.sh

minify:
	go run extra/minify.go
	suffix=-minified bash extra/test.sh
