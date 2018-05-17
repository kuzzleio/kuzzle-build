#!/bin/bash

brew update || echo 'up to date'

brew install expect docker docker-compose docker-machine xhyve docker-machine-driver-xhyve

sudo chown root:wheel $(brew --prefix)/opt/docker-machine-driver-xhyve/bin/docker-machine-driver-xhyve
sudo chmod u+s $(brew --prefix)/opt/docker-machine-driver-xhyve/bin/docker-machine-driver-xhyve

sudo docker-machine create default --driver xhyve --xhyve-experimental-nfs-share

sudo eval $(docker-machine env default)

sudo docker run -t hello-world