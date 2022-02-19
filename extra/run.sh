#!/bin/bash
set -eou pipefail

source $(dirname $(dirname $0))/extra/cleanup.sh

docker compose --profile=run up --abort-on-container-exit
