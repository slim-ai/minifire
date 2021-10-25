#!/bin/bash
set -eou pipefail

source extra/test.sh

cat $files | docker-trace minify $container $container_minified

test_get $container_minified google.com
test_get $container_minified http://google.com
test_get $container_minified https://google.com

(
    docker images --format '{{.Repository}}:{{.Tag}} {{.CreatedAt}} {{.Minify}}' $container          | tail -n1
    docker images --format '{{.Repository}}:{{.Tag}} {{.CreatedAt}} {{.Minify}}' $container_minified | tail -n1
) | column -t
