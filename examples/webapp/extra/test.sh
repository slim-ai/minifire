#!/bin/bash
set -eou pipefail

monitor=no source extra/run.sh

docker run --rm -v$(pwd):/code --network host webapp:test

docker kill $(echo $(docker ps --format "{{.Image}} {{.ID}}" | grep ^$name:)) &>/dev/null || true
