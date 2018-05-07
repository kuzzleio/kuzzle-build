#!/bin/bash

remove_container() {
    docker kill $CONTAINER_NAME > /dev/null
}

DIST=$1
IMAGE_NAME=kuzzleio/setupsh-test
CONTAINER_NAME=setupsh-test

echo
echo "$(tput bold) Setup.sh test suite"
echo " ================================$(tput sgr0)"
echo
echo " Setting up test environment... ($DIST)"

# Build and start docker container
docker build -f test/Dockerfile.$1 . -t $IMAGE_NAME > /dev/null
docker run -d --privileged --rm --name $CONTAINER_NAME -v $PWD:/opt $IMAGE_NAME > /dev/null

trap remove_container INT
trap remove_container EXIT

# Test 1 - Check curl
#########################################

docker exec -t $CONTAINER_NAME sh -c "./setupsh.should \"fail if curl is not installed\" \"This script needs curl\" 43"

if [ $? -ne "0" ]; then
    exit "$?"
fi

# Test 2
#########################################

# Setup (install curl and shut eth0 down)
echo " Installing curl..."
docker exec -t $CONTAINER_NAME /opt/test/fixtures-setupsh/install-curl.sh > /dev/null
echo " Shutting down eth0..."
docker exec -t $CONTAINER_NAME ip link set down dev eth0

# Check internet
docker exec -t $CONTAINER_NAME sh -c "./setupsh.should \"fail if offline\" \"No internet\" 42"

if [ $? -ne "0" ]; then
    exit $?
fi

# Teardown (switch eth0 on)
echo " Bringing up eth0..."
docker exec -t $CONTAINER_NAME ip link set up dev eth0
docker exec -t $CONTAINER_NAME ip r a default via 172.17.0.1 dev eth0


# Test 3 - Check docker
#########################################

docker exec -t $CONTAINER_NAME sh -c "./setupsh.should \"fail if docker is not installed\" \"You need docker to run Kuzzle\" 44"

if [ $? -ne "0" ]; then
    exit $?
fi

# Test 4 - Check docker-compose
#########################################

# Setup (install docker)
echo " Installing docker..."
docker exec -t $CONTAINER_NAME /opt/test/fixtures-setupsh/install-docker.sh > /dev/null

# Check docker-compose
docker exec -t $CONTAINER_NAME sh -c "./setupsh.should \"fail if docker-compose is not installed\" \"You need docker-compose to be able to run Kuzzle\" 44"

if [ $? -ne "0" ]; then
    exit $?
fi


# Test 5 - Check vm_map_maxcount parameter
#########################################

# Setup (install docker-compose)
echo " Installing docker-compose..."
docker exec -t $CONTAINER_NAME /opt/test/fixtures-setupsh/install-docker-compose.sh > /dev/null
echo " Setting bad vm.max_map_count..."
docker exec -t $CONTAINER_NAME /opt/test/fixtures-setupsh/set-map-count.sh 242144 > /dev/null

# Check vm.max_map_count
docker exec -t $CONTAINER_NAME sh -c "./setupsh.should \"fail if vm.max_map_count is too low\" \"The current value of the kernel configuration variable vm.max_map_count\" 44"

if [ $? -ne "0" ]; then
    exit $?
fi

echo " Setting proper vm.max_map_count..."
docker exec -t $CONTAINER_NAME /opt/test/fixtures-setupsh/set-map-count.sh 262144 > /dev/null


# Test 6 - Pull Kuzzle
#########################################
docker exec -t $CONTAINER_NAME sh -c "./setupsh.should \"fail if dockerd is not running\" \"Pull failed.\" 1"

echo " Setting launching dockerd..."
docker exec -t $CONTAINER_NAME /opt/test/fixtures-setupsh/launch-dockerd.sh


# Test - Kuzzle works fine!
#########################################

docker exec -t $CONTAINER_NAME sh -c "./setupsh.should \"install Kuzzle without problems\" \"Kuzzle successfully installed\" 0"
exit $?

# Teardown
remove_container