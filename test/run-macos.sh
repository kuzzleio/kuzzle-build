#!/bin/bash

set -e

brew update || echo 'up to date'

brew install expect docker docker-compose docker-machine xhyve docker-machine-driver-xhyve

docker-machine create default --driver xhyve --xhyve-experimental-nfs-share

eval $(docker-machine env default)

docker run -t hello-world