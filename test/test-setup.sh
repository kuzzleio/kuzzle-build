#!/bin/bash

remove_container() {
    echo "Removing container..."
    docker kill $CONTAINER_NAME > /dev/null
    echo "Done."
}

DIST=$1

if [ "$2" = "--show-debug" ]; then
    OUTPUT=""
    export SETUPSH_LOG_USER=1
else
    OUTPUT="> /dev/null"
fi

IMAGE_NAME=kuzzleio/setupsh-test-$DIST
CONTAINER_NAME=setupsh-test-$DIST

echo
echo "$(tput bold) Testing Setup.sh on $DIST"
echo " ================================$(tput sgr0)"
echo
echo " Setting up test environment..."

# Build and start docker container
sh -c "docker run -d -e SETUPSH_LOG_USER -e COMPOSE_HTTP_TIMEOUT -e DOCKER_CLIENT_TIMEOUT --privileged --rm --name $CONTAINER_NAME -v $PWD:/opt $IMAGE_NAME $OUTPUT"
EXIT_VALUE=$?
if [ $EXIT_VALUE -ne 0 ]; then
    exit $EXIT_VALUE
fi

trap remove_container INT
trap remove_container EXIT

echo

# Test - Check curl
#########################################

# We only test curl if the tested distribution comes without it
# echo $(docker exec -t $CONTAINER_NAME sh -c "command -v curl")

if [ -z $(docker exec -t $CONTAINER_NAME sh -c "command -v curl") ]; then
    docker exec -t $CONTAINER_NAME sh -ec "./setupsh.should \"fail if curl is not installed\" \"This script needs curl\" 43 && echo Ok > /dev/null"
    EXIT_VALUE=$?
    if [ $EXIT_VALUE -ne 0 ]; then
        exit $EXIT_VALUE
    fi
fi


# Test - Check internet connection
#########################################

# Setup (install curl and shut eth0 down)
echo " Installing curl..."
sh -c "docker exec -t $CONTAINER_NAME /opt/test/fixtures-setupsh/install-curl.sh $OUTPUT" 
echo " Shutting down eth0..."
docker exec -t $CONTAINER_NAME ip link set down dev eth0

# Check internet
docker exec -t $CONTAINER_NAME sh -ec "./setupsh.should \"fail if offline\" \"No internet\" 42 && echo Ok > /dev/null"
EXIT_VALUE=$?
if [ "$EXIT_VALUE" != 0 ]; then
    echo "Exit value is $EXIT_VALUE"
    exit 1
fi

# Teardown (switch eth0 back on)
echo " Bringing up eth0..."
docker exec -t $CONTAINER_NAME ip link set up dev eth0
docker exec -t $CONTAINER_NAME ip r a default via 172.17.0.1 dev eth0


# Test - Check docker
#########################################

docker exec -t $CONTAINER_NAME sh -c "./setupsh.should \"fail if docker is not installed\" \"You need docker to run Kuzzle\" 44 && echo Ok > /dev/null"
EXIT_VALUE=$?
if [ $EXIT_VALUE -ne 0 ]; then
    exit $EXIT_VALUE
fi


# Test - Check docker-compose
#########################################

# Setup (install docker)
echo " Installing docker..."
sh -c "docker exec -t $CONTAINER_NAME /opt/test/fixtures-setupsh/install-docker.sh $OUTPUT"

# Check docker-compose
docker exec -t $CONTAINER_NAME sh -c "./setupsh.should \"fail if docker-compose is not installed\" \"You need docker-compose to be able to run Kuzzle\" 44 && echo Ok > /dev/null"
EXIT_VALUE=$?
if [ $EXIT_VALUE -ne 0 ]; then
    exit $EXIT_VALUE
fi


# Test - Check the existence of sysctl
#########################################

# Setup (install docker-compose)
echo " Installing docker-compose..."
sh -c "docker exec -t $CONTAINER_NAME /opt/test/fixtures-setupsh/install-docker-compose.sh $OUTPUT"

# Check if sysctl exists
if [ -z $(docker exec -t $CONTAINER_NAME sh -c "command -v sysctl") ]; then
    docker exec -t $CONTAINER_NAME sh -c "./setupsh.should \"fail if sysctl is not installed\" \"This script needs sysctl\" 44 && echo Ok > /dev/null"
    EXIT_VALUE=$?
    if [ $EXIT_VALUE -ne 0 ]; then
        exit $EXIT_VALUE
    fi
fi


# Test - Check vm_map_maxcount parameter
#########################################

# Setup (install sysctl and set bad value)
echo " Installing sysctl..."
sh -c "docker exec -t $CONTAINER_NAME /opt/test/fixtures-setupsh/install-sysctl.sh $OUTPUT"
echo " Setting bad vm.max_map_count..."
sh -c "docker exec -t $CONTAINER_NAME /opt/test/fixtures-setupsh/set-map-count.sh 242144 $OUTPUT"

# Check vm.max_map_count
docker exec -t $CONTAINER_NAME sh -c "./setupsh.should \"fail if vm.max_map_count is too low\" \"The current value of the kernel configuration variable vm.max_map_count\" 44 && echo Ok > /dev/null"
EXIT_VALUE=$?
if [ $EXIT_VALUE -ne 0 ]; then
    exit $EXIT_VALUE
fi

echo " Setting proper vm.max_map_count..."
sh -c "docker exec -t $CONTAINER_NAME /opt/test/fixtures-setupsh/set-map-count.sh 262144 $OUTPUT"


# Test - Download docker-compose.yml
#########################################

# Setup (redirect kuzzle.io to 127.0.0.1)
echo " Killing kuzzle.io..."
docker exec -t $CONTAINER_NAME sh -c "echo \"127.0.0.1 kuzzle.io\" >> /etc/hosts"

# Check vm.max_map_count
docker exec -t $CONTAINER_NAME sh -c "./setupsh.should \"fail if downloading docker-compose.yml fails\" \"Cannot download\" 45 && echo Ok > /dev/null"
EXIT_VALUE=$?
if [ $EXIT_VALUE -ne 0 ]; then
    exit $EXIT_VALUE
fi

# Teardown (clean-up /etc/hosts)
echo " Restoring kuzzle.io..."
# Note: sed -i works badly in a Docker container
docker exec -t $CONTAINER_NAME sh -c "cp /etc/hosts ~/hosts.new; sed -i '/kuzzle.io/d' ~/hosts.new; cp -f ~/hosts.new /etc/hosts"


# Test - Pull Kuzzle
#########################################
docker exec -t $CONTAINER_NAME sh -c "./setupsh.should \"fail if dockerd is not running\" \"Pull failed.\" 1 && echo Ok > /dev/null"
EXIT_VALUE=$?
if [ $EXIT_VALUE -ne 0 ]; then
    exit $EXIT_VALUE
fi

echo " Launching dockerd..."
sh -c "docker exec -t $CONTAINER_NAME /opt/test/fixtures-setupsh/launch-dockerd.sh $OUTPUT &"


# Test - Kuzzle works fine!
#########################################

docker exec -t $CONTAINER_NAME sh -c "./setupsh.should \"run Kuzzle successfully\" \"Kuzzle successfully installed\" 0 && echo Ok > /dev/null"
EXIT_VALUE=$?

exit $EXIT_VALUE