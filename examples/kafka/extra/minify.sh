#!/bin/bash
set -eou pipefail

source extra/cleanup.sh

# start trace
killall docker-trace -s INT || true
docker-trace files > /tmp/files.txt 2> /tmp/files.err &
trace_pid=$!
echo wait for trace to start
tail -f /tmp/files.err | while read line; do
    if [ $line = ready ]; then
        echo trace started
        break
    fi
done || true

sleep 5 # why do traces need a second to startup?

# test
docker compose  --profile=run up -d
docker compose --profile=test up -d
docker compose logs -f &
docker wait $(docker compose ps --format json | jq -c .[] | grep test | jq -r .ID)
if [ 0 != $(docker compose ps --format json | jq -c .[] | grep test | jq -r .ExitCode) ]; then
    echo tests failed
    exit 1
fi
docker compose --profile=all kill &>/dev/null || true

# stop trace
killall docker-trace -s INT || true

# minify
docker compose ps --format json | jq -c .[] | grep -v test | while read line; do
    container_id=$(echo "$line" | jq -r .ID)
    service=$(echo "$line" | jq -r .Service)
    container_in=$(eval "echo $(cat docker-compose.yml | yq .services.${service}.image)")
    container_out=${container_in}-minified
    echo minify $container_id $container_in "=>" $container_out $(cat /tmp/files.txt | grep ^$container_id | wc -l)
    cat /tmp/files.txt | grep ^$container_id | awk '{print $2}' | docker-trace minify $container_in $container_out
done
