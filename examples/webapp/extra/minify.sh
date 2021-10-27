#!/bin/bash
set -eou pipefail

source extra/cleanup.sh

# start trace
docker-trace files > /tmp/files.txt 2> /tmp/files.err &
trace_pid=$!
echo wait for trace to start
tail -f /tmp/files.err | while read line; do
    if [ $line = ready ]; then
        echo trace started
        break
    fi
done || true

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
kill $trace_pid
wait $trace_pid

# minify
docker compose ps --format json | jq -c .[] | while read line; do
    service=$(echo "$line" | jq -r .Service)
    id=$(echo "$line" | jq -r .ID)
    container_in=webapp:${service}
    container_out=webapp:${service}-minified
    echo minify $container_in "=>" $container_out
    cat /tmp/files.txt | grep ^$id | awk '{print $2}' | docker-trace minify $container_in $container_out
done

# test minified
export suffix="-minified"
docker compose  --profile=run up -d
docker compose --profile=test up -d
docker compose logs -f &
docker wait $(docker compose ps --format json | jq -c .[] | grep test | jq -r .ID)
if [ 0 != $(docker compose ps --format json | jq -c .[] | grep test | jq -r .ExitCode) ]; then
    echo minified tests failed
    exit 1
fi
