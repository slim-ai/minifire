#!/bin/bash
set -eou pipefail

source extra/cleanup.sh

docker compose --profile=dev up
