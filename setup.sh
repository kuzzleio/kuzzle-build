#!/bin/bash
set -e

# list of colors
RED="\\033[1;31m"
BLUE="\\033[1;34m"
GREEN="\\033[1;32m"
NORMAL="\\033[0;39m"
RT="\r\n"

CURRENT_OS=Unknown
OS_IS_SUPPORTED=0

# Output a text with the selected color (reinit to normal at the end)
write() {
  echo -e " $1$2" "$NORMAL" >&2
}

command_exists() {
  command -v "$@" > /dev/null 2>&1
}

checkRoot() {
  if [ "$EUID" -ne 0 ]; then
    echo
    echo "This script needs to be executed with root privileges."
    echo
    exit
  fi
}

findOSType()
{
  echo "Determining os type..."
  echo
  osType=$(uname)
  if [ "$osType" == "Linux" ]; then
    if [ -f /etc/os-release ]; then
      distro=$(awk -F= '/^NAME/{print $2}' /etc/os-release)
    else
      distro=$(ls -d /etc/[A-Za-z]*[_-][rv]e[lr]* | grep -v "lsb" | cut -d'/' -f3 | cut -d'-' -f1 | cut -d'_' -f1)
    fi
    CURRENT_OS=$(echo $distro | tr 'a-z' 'A-Z' | cut -d' ' -f1 | tr -d '"')
  fi
}

isOSSupported()
{
  # echo "Detected OS is" $CURRENT_OS
  case "$CURRENT_OS" in
    "UBUNTU" | "DEBIAN")
    {
      echo "$CURRENT_OS is well supported."
      OS_IS_SUPPORTED=1
    } ;;
    *)
    {
      echo "$CURRENT_OS is not supported."
      OS_IS_SUPPORTED=0
      while [[ "$proceedNotSupported" != [yYnN] ]]
      do
        echo -n "Do you want to continue anyway? (y/N) "
        read proceedNotSupported trash
        case "$proceedNotSupported" in
          [yY])
            echo
            echo "Ok. We encourage you to send us feedback at tech@kuzzle.io"
            ;;
          [nN] | '')
            echo
            echo "Aborting."
            exit 1
            ;;
          *)
            echo
            echo "I did not understand your answer."
            ;;
        esac
      done
    } ;;
  esac
}

installDocker() {
  echo
  echo "This script needs Docker, but it does not seem to be installed."
  echo "This script can install Docker for you, otherwise you can do it manually"
  echo "(you can find exhaustive instructions at https://docs.docker.com/engine/installation/"
  echo
  while [[ "$installDocker" != [yYnN] ]]
  do
    echo -n "Do you want to install Docker now? (y/N) "
    read installDocker trash
    case $installDocker in
      [yY])
        echo
        if command_exists curl; then
          echo "Installing Docker..."
          curl -sSL https://get.docker.com/ | sh
        else
          echo "This script needs curl to launch the Docker installation script,"
          echo "but it does not seem to be installed on your system."
          echo "Please install it and re-run this script."
          exit 1
        fi
        ;;
      [nN] | '')
        echo
        echo "Aborting. "
        exit 1
        ;;
      *)
        echo
        echo "I did not understand your answer."
        ;;
    esac
  done
}

runDocker() {
  echo
  echo "Docker does not seem to be running on your system. This script can start it for you,"
  echo "or you can do it manually."
  echo
  while [[ "$runDocker" != [yYnN] ]]
  do
    echo -n "Do you want to run Docker now? (y/N) "
    read  runDocker
    case "$runDocker" in
      [yY])
        ;;
      [nN] | '')
        ;;
      *)
      echo
      echo "I did not understand your answer."
      ;;
    esac
  done
}

installDockerCompose() {
  echo
  echo "This script needs Docker Compose, but it does not seem to be installed."
  echo "This script can install Docker Compose for you, otherwise you can do it manually"
  echo "(you can find exhaustive instructions at https://docs.docker.com/compose/install/"
  echo
  while [[ "$installDockerCompose" != [yYnN] ]]
  do
    echo -n "Do you want to install Docker Compose now? (y/N) "
    read installDockerCompose
    case "$installDockerCompose" in
      [yY])
        if command_exists curl; then
          echo "Installing Docker Compose..."
          curl -L "https://github.com/docker/compose/releases/download/1.10.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
          chmod +x /usr/local/bin/docker-compose
        else
          echo "This script needs curl to launch the Docker Compose installation script,"
          echo "but it does not seem to be installed on your system."
          echo "Please install it and re-run this script."
          exit -1
        fi
        ;;
      [nN] | '')
        echo
        echo "Aborting. "
        exit -1
        ;;
      *)
        echo
        echo "I did not understand your answer."
        ;;
    esac
  done
}

setupMapCount() {
  REQUIRED_MAP_COUNT=262144
  SYSCTL_CONF_FILE=/etc/sysctl.conf
  MAP_COUNT=$(sysctl -a | grep vm.max_map_count | cut -d'=' -f2 | tr -d ' ')

  if [ -z "$MAP_COUNT" ] || [ $MAP_COUNT -lt $REQUIRED_MAP_COUNT ]; then
    echo
    echo "Kuzzle needs the kernel configuration variable vm.max_map_count to be set to at least $REQUIRED_MAP_COUNT,"
    echo "but it seems to be set to $MAP_COUNT on your system."
    echo "This script can set it automatically or you can do it manually."
    echo
    while [[ "$setVmParam" != [yYnN] ]]
    do
      echo -n "Do you want to set the vm.max_map_count now? (y/N) "
      read setVmParam
      case "$setVmParam" in
        [yY])
          sysctl -w vm.max_map_count=$REQUIRED_MAP_COUNT
          if [ -z "$MAP_COUNT" ]; then
            echo "vm.max_map_count=$REQUIRED_MAP_COUNT" > $SYSCTL_CONF_FILE
          else
            sed 's/vm.max_map_count=.+/vm.max_map_count=$REQUIRED_MAP_COUNT/g' $SYSCTL_CONF_FILE > $SYSCTL_CONF_FILE
          fi
          ;;
        [nN] | '')
          echo
          echo "Aborting."
          exit 1
          ;;
        *)
        echo
        echo "I did not understand your answer."
        ;;
      esac
    done
  fi
}

collectPersonalData() {
  echo
  echo "We'd be happy to know a little bit about you."
  echo
  echo -n "What's your email address? (press Enter to skip)"
  read email trash
  echo
  echo -n "What's your name? (press Enter to skip)"
  read firstName lastName otherName yetAnotherName trash
  echo "What do you plan to use Kuzzle for? (press Enter to skip)"
  read purpose
  # TODO send collected data to analytics service
}

startKuzzle() {
  echo
  echo "Starting Kuzzle..."
  echo
  composerYMLURL="https://raw.githubusercontent.com/kuzzleio/kuzzle-build/master/docker-compose/kuzzle-docker-compose.yml"
  composerYMLPath="kuzzle-docker-compose.yml"
  curl -XGET $composerYMLURL > $composerYMLPath
  docker-compose -f $composerYMLPath up -d
  echo
  echo "Kuzzle is up and running!"
  echo
  echo "Where do we go from here?"
  echo "* You can see the logs of your Kuzzle stack by typing:"
  echo "  docker-compose -f $composerYMLPath logs"
  echo "* You can check if everything is working by typing:"
  echo "  curl -XGET http://localhost:7511/"
  echo "* You can stop the Kuzzle stack by typing:"
  echo "  docker-compose -f $composerYMLPath stop"
  echo "* You can restart the Kuzzle stack by typing:"
  echo "  docker-compose -f $composerYMLPath restart"
  echo "* You can read the docs at http://docs.kuzzle.io/"
}

# Main execution routine
# ===========================

checkRoot
findOSType
isOSSupported

if ! command_exists docker; then
  installDocker
fi

if ! $(docker run hello-world > /dev/null); then
  echo
  echo "Docker does not seem to be running on your system."
  echo "Please start the Docker daemon and re-run this script"
  echo "More information at https://docs.docker.com/engine/admin/"
  exit
fi

if ! command_exists docker-compose; then
  installDockerCompose
fi

setupMapCount
collectPersonalData
startKuzzle
