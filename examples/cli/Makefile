.PHONY: build test minify

build:
	@docker build --file extra/Dockerfile --tag cli --network host .

test:
	@bash extra/test.sh

minify:
	@bash extra/minify.sh
