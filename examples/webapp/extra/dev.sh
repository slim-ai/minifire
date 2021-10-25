#!/bin/bash
set -eou pipefail

# colors
end="\033[0m"; black="\033[0;30m"; white="\033[0;37m"; red="\033[0;31m"; green="\033[0;32m"; yellow="\033[0;33m"; blue="\033[0;34m"; purple="\033[0;35m"; lightblue="\033[0;36m"; black() { echo -e "${black}${1}${end}"; }; white() { echo -e "${white}${1}${end}"; }; red() { echo -e "${red}${1}${end}"; }; green() { echo -e "${green}${1}${end}"; }; yellow() { echo -e "${yellow}${1}${end}"; }; blue() { echo -e "${blue}${1}${end}"; }; purple() { echo -e "${purple}${1}${end}"; }; lightblue() { echo -e "${lightblue}${1}${end}"; }

name=webapp

trap 'docker kill $(echo $(docker ps --format "{{.Image}} {{.ID}}" | grep ^webapp:)) &>/dev/null || true' EXIT

running() {
    docker ps --format '{{.Image}} {{.ID}}' | grep ^$name: || true
}

run_dev() {
    tag=$1
    color=$2
    container=$name:$tag
    id=$(docker run --rm -t -d -v$(pwd):/code --network host --entrypoint "" $container bash /code/extra/entrypoint_dev_${tag}.sh )
    docker logs -f $id | sed "s/^/$($color $tag): /" &
}

if [ -n "$(running)" ]; then
    echo kill existing containers:
    echo "$(running)"
    echo "$(running)" | awk '{print $2}' | xargs docker kill
    echo
fi

# start app autoreloading
run_dev backend  red
run_dev frontend green
run_dev database blue

# warm the site with an ignored test run
docker run --rm -it -v$(pwd):/code --network host webapp:test &>/dev/null || true

# start tests autoreloading
run_dev test     yellow

while true; do
    num=$(running | wc -l)
    expected=4
    if [ $expected != $num ]; then
        echo $(red "FATAL needed $expected running containers, found $num")
        exit 1
    fi
    sleep 1
done
