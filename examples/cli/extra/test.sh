#!/bin/bash
set -eou pipefail

container=cli:latest
container_minified=cli:minified
rm -f /tmp/temp.cli.*
stdout=$(mktemp /tmp/temp.cli.XXXX)
stderr=$(mktemp /tmp/temp.cli.XXXX)
files=$(mktemp  /tmp/temp.cli.XXXX)

test_get() {
    container=$1
    url=$2
    id=$(docker create --network host $container $url)
    docker-trace files --start $id 1>> $files 2>/dev/null
    docker logs $id 1> $stdout 2> $stderr
    actual="$(cat $stderr | head -n1 | awk '{print $NF}')"
    status="301"
    if [ "$status" != "$actual" ]; then
        echo FAILURE
        echo expected: "$status"
        echo got: "$actual"
        return 1
    fi
    body='The document has moved'
    if ! cat $stdout | grep "$body" &>/dev/null; then
        echo FAILURE
        echo expected: "$body"
        echo got: "$stdout"
        return 1
    fi
    echo SUCCESS $container $url
}

test_get $container google.com
test_get $container http://google.com
test_get $container https://google.com
