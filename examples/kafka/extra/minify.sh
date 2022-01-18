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


sleep 5 # why is zookeeper not building?

# test
docker compose  --profile=run up -d

docker compose --profile=test up -d
docker compose logs -f | grep test &
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
    service=$(echo "$line" | jq -r .Service)
    id=$(echo "$line" | jq -r .ID)
    container_id=$(docker compose images ${service} -q)
    container_in=$(docker images --no-trunc|grep $container_id|awk '{print $1 ":" $2}' | head -n1)
    container_out=${container_in}-minified
    echo minify $id $container_in "=>" $container_out $(cat /tmp/files.txt | grep ^$id | wc -l)
    cat /tmp/files.txt | grep ^$id | awk '{print $2}' | docker-trace minify $container_in $container_out
done

# test minified
export suffix="-minified"
docker compose  --profile=run up -d

docker compose --profile=test up -d
docker compose logs -f | grep test &
docker wait $(docker compose ps --format json | jq -c .[] | grep test | jq -r .ID)
if [ 0 != $(docker compose ps --format json | jq -c .[] | grep test | jq -r .ExitCode) ]; then
    echo minified tests failed
    exit 1
fi
