#!/bin/bash

set -x

brew install expect docker docker-compose docker-machine
brew cask install virtualbox

# sudo chown root:wheel /usr/local/opt/docker-machine-driver-xhyve/bin/docker-machine-driver-xhyve
# sudo chmod u+s /usr/local/opt/docker-machine-driver-xhyve/bin/docker-machine-driver-xhyve

curl --create-dirs -Lo ~/.docker/machine/cache/boot2docker.iso https://github.com/boot2docker/boot2docker/releases/download/v1.9.1/boot2docker.iso
docker-machine --github-api-token=$GITHUB_TOKEN --virtualbox-no-vtx-check --driver virtualbox create default 

sudo eval $(docker-machine env default)

sudo docker run -t hello-world