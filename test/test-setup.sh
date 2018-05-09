#!/bin/bash

remove_container() {
    docker kill $CONTAINER_NAME > /dev/null
}

DIST=$1

if [ "$2" = "--show-debug" ]; then
    OUTPUT=""
else
    OUTPUT="> /dev/null"
fi

IMAGE_NAME=kuzzleio/setupsh-test-$DIST
CONTAINER_NAME=setupsh-test

echo
echo "$(tput bold) Testing Setup.sh on $DIST"
echo " ================================$(tput sgr0)"
echo
echo " Setting up test environment..."

# Build and start docker container
# docker build -f test/Dockerfile.$1 . -t $IMAGE_NAME $OUTPUT
docker run -d -e SETUPSH_LOG_USER --privileged --rm --name $CONTAINER_NAME -v $PWD:/opt $IMAGE_NAME $OUTPUT

trap remove_container INT
trap remove_container EXIT


# Test - Check curl
#########################################

docker exec -t $CONTAINER_NAME sh -c "./setupsh.should \"fail if curl is not installed\" \"This script needs curl\" 43"

if [ $? -ne "0" ]; then
    exit "$?"
fi


# Test - Check internet connection
#########################################

# Setup (install curl and shut eth0 down)
echo " Installing curl..."
docker exec -t $CONTAINER_NAME /opt/test/fixtures-setupsh/install-curl.sh $OUTPUT
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


# Test - Check docker
#########################################

docker exec -t $CONTAINER_NAME sh -c "./setupsh.should \"fail if docker is not installed\" \"You need docker to run Kuzzle\" 44"

if [ $? -ne "0" ]; then
    exit $?
fi


# Test - Check docker-compose
#########################################

# Setup (install docker)
echo " Installing docker..."
docker exec -t $CONTAINER_NAME /opt/test/fixtures-setupsh/install-docker.sh $OUTPUT

# Check docker-compose
docker exec -t $CONTAINER_NAME sh -c "./setupsh.should \"fail if docker-compose is not installed\" \"You need docker-compose to be able to run Kuzzle\" 44"

if [ $? -ne "0" ]; then
    exit $?
fi


# Test - Check vm_map_maxcount parameter
#########################################

# Setup (install docker-compose)
echo " Installing docker-compose..."
docker exec -t $CONTAINER_NAME /opt/test/fixtures-setupsh/install-docker-compose.sh $OUTPUT
echo " Setting bad vm.max_map_count..."
docker exec -t $CONTAINER_NAME /opt/test/fixtures-setupsh/set-map-count.sh 242144 $OUTPUT

# Check vm.max_map_count
docker exec -t $CONTAINER_NAME sh -c "./setupsh.should \"fail if vm.max_map_count is too low\" \"The current value of the kernel configuration variable vm.max_map_count\" 44"

if [ $? -ne "0" ]; then
    exit $?
fi

echo " Setting proper vm.max_map_count..."
docker exec -t $CONTAINER_NAME /opt/test/fixtures-setupsh/set-map-count.sh 262144 $OUTPUT


# Test - Download docker-compose.yml
#########################################

# Setup (redirect kuzzle.io to 127.0.0.1)
echo " Killing kuzzle.io..."
docker exec -t $CONTAINER_NAME sh -c "echo \"127.0.0.1 kuzzle.io\" >> /etc/hosts"

# Check vm.max_map_count
docker exec -t $CONTAINER_NAME sh -c "./setupsh.should \"fail if downloading docker-compose.yml fails\" \"Cannot download\" 45"

if [ $? -ne "0" ]; then
    exit $?
fi

# Teardown (clean-up /etc/hosts)
echo " Restoring kuzzle.io..."
# Note: sed -i works badly in a Docker container
docker exec -t $CONTAINER_NAME sh -c "cp /etc/hosts ~/hosts.new; sed -i '/kuzzle.io/d' ~/hosts.new; cp -f ~/hosts.new /etc/hosts"


# Test - Pull Kuzzle
#########################################
docker exec -t $CONTAINER_NAME sh -c "./setupsh.should \"fail if dockerd is not running\" \"Pull failed.\" 1"

if [ $? -ne "0" ]; then
    exit $?
fi

echo " Launching dockerd..."
docker exec -t $CONTAINER_NAME /opt/test/fixtures-setupsh/launch-dockerd.sh & $OUTPUT


# Test - Kuzzle works fine!
#########################################

docker exec -t $CONTAINER_NAME sh -c "./setupsh.should \"install Kuzzle without problems\" \"Kuzzle successfully installed\" 0"
exit $?

# Teardown
remove_container