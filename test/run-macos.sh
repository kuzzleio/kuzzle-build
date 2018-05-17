#!/bin/bash

set -x

brew update || echo 'up to date'

brew install expect docker docker-compose docker-machine xhyve docker-machine-driver-xhyve

sudo chown root:wheel /usr/local/opt/docker-machine-driver-xhyve/bin/docker-machine-driver-xhyve
sudo chmod u+s /usr/local/opt/docker-machine-driver-xhyve/bin/docker-machine-driver-xhyve

curl --create-dirs -Lo ~/.docker/machine/cache/boot2docker.iso https://github.com/boot2docker/boot2docker/releases/download/v1.9.1/boot2docker.iso
docker-machine --github-api-token=$GITHUB_TOKEN create default --driver xhyve --xhyve-experimental-nfs-share

sudo eval $(docker-machine env default)

sudo docker run -t hello-world