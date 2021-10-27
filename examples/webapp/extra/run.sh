#!/bin/bash
set -eou pipefail

source extra/cleanup.sh

docker compose --profile=run up --abort-on-container-exit
