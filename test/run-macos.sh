#!/bin/bash

set -e

brew install expect docker docker-compose docker-machine xhyve docker-machine-driver-xhyve

docker-machine create default --driver xhyve --xhyve-experimental-nfs-share

eval $(docker-machine env default)