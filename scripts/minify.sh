#!/bin/bash
set -euo pipefail

dir=$(dirname $(realpath $0))

source $dir/cleanup.sh

hash=$(md5sum $dir/minify.go | awk '{print $1}')

if ! ls $dir/minify.$hash &>/dev/null; then (
    cd $dir
    (ls minify.* | grep -v -e .go -e .sh | xargs rm -f) || true
    CGO_ENABLED=0 go build -ldflags='-s -w' -tags 'netgo osusergo' -o minify.$hash minify.go
) fi

$dir/minify.$hash

suffix=-minified bash $dir/test.sh
