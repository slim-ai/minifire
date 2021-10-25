#!/bin/bash
set -eou pipefail

trap 'docker kill $(echo $(docker ps --format "{{.Image}} {{.ID}}" | grep -e ^docker-trace:bpftrace -e ^$name:)) &>/dev/null || true' EXIT

source extra/test.sh

tags='
    frontend
    backend
    database
'

for tag in $tags; do
    container=$name:$tag
    container_minified=$name:${tag}-minified
    echo minify $container $container_minified
    cat /tmp/temp.$name:$tag.* | docker-trace minify $container $container_minified
done

suffix="-minified" source extra/test.sh

for tag in $tags; do
    container=$name:$tag
    container_minified=$name:${tag}-minified
    docker images --format '{{.Repository}}:{{.Tag}} {{.CreatedAt}} {{.Size}}' $container          | tail -n1
    docker images --format '{{.Repository}}:{{.Tag}} {{.CreatedAt}} {{.Size}}' $container_minified | tail -n1
done | column -t
