#!/bin/bash
set -eou pipefail

docker compose kill &>/dev/null || true; docker compose rm -f &>/dev/null || true

trap "docker compose --profile=all kill &>/dev/null || true; docker compose --profile=all rm -f &>/dev/null || true" INT EXIT TERM
