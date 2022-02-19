#!/bin/bash
set -eou pipefail

source $(dirname $(dirname $0))/extra/cleanup.sh

docker compose  --profile=run up -d
docker compose --profile=test up -d
docker compose logs -f &
docker wait $(docker compose ps --format json | jq -c .[] | grep test | jq -r .ID)
exit $(docker compose ps --format json | jq -c .[] | grep test | jq -r .ExitCode)
