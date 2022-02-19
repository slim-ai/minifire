#!/bin/bash
set -xeuo pipefail
hash=$(md5sum extra/minify.go | awk '{print $1}')
if ! ls ./minify.$hash &>/dev/null; then
    rm -f minify.*
    CGO_ENABLED=0 go build -ldflags='-s -w' -tags 'netgo osusergo' -o minify.$hash extra/minify.go
fi
./minify.$hash
suffix=-minified bash extra/test.sh
