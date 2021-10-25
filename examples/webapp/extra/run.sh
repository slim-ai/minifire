#!/bin/bash
set -eou pipefail

# colors
end="\033[0m"; black="\033[0;30m"; white="\033[0;37m"; red="\033[0;31m"; green="\033[0;32m"; yellow="\033[0;33m"; blue="\033[0;34m"; purple="\033[0;35m"; lightblue="\033[0;36m"; black() { echo -e "${black}${1}${end}"; }; white() { echo -e "${white}${1}${end}"; }; red() { echo -e "${red}${1}${end}"; }; green() { echo -e "${green}${1}${end}"; }; yellow() { echo -e "${yellow}${1}${end}"; }; blue() { echo -e "${blue}${1}${end}"; }; purple() { echo -e "${purple}${1}${end}"; }; lightblue() { echo -e "${lightblue}${1}${end}"; }

name=webapp

trap 'docker kill $(echo $(docker ps --format "{{.Image}} {{.ID}}" | grep ^webapp: | grep -v ^webapp:test)) &>/dev/null || true' EXIT

running() {
     docker ps --format '{{.Image}} {{.ID}}' | grep ^$name: | grep -v ^$name:test || true
}

rm -f /tmp/temp.$name:*

files() {
    mktemp /tmp/temp.$name:$1.XXXX
}

run() {
    tag=$1${suffix:-}
    color=$2
    container=$name:$tag
    uid=$(uuidgen)
    id=$(docker create --name $uid --rm --network host $container)
    docker-trace files --start $id 1>> $(files $tag) &
    while true; do
        docker ps --no-trunc --format '{{.ID}}' | grep $id || continue
        if docker logs -f $id | sed "s/^/$($color $tag): /"; then
            break
        else
            continue
        fi
        sleep .1
    done &
}

if [ -n "$(running)" ]; then
    echo kill existing containers:
    echo "$(running)"
    echo "$(running)" | awk '{print $2}' | xargs docker kill
    echo
fi

run backend  red
run frontend green
run database blue

expected=3

while true; do
    num=$(running | wc -l)
    if [ $expected = $num ]; then
        break
    fi
    echo waiting for containers to start
    running
    sleep 1
done

if [ "${monitor:-yes}" = "yes" ]; then
    while true; do
        num=$(running | wc -l)
        if [ $expected != $num ]; then
            echo $(red "FATAL needed $expected running containers, found $num")
            exit 1
        fi
        sleep 1
    done
fi
