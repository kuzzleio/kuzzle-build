#!/bin/bash

# Variables
KUZZLE_DIR="./kuzzle"
KUZZLE_DOWNLOAD_MANAGER=""
KUZZLE_PUSH_ANALYTICS=""
KUZZLE_CHECK_DOCKER_COMPOSE_YML_HTTP_STATUS_CODE=""
KUZZLE_CHECK_CONNECTIVITY_CMD=""
CURL_OPTS="-sSL"
CURL_PUSH_OPTS="-H Content-Type:application/json --data "
WGET_OPTS="-qO-"
WGET_PUSH_OPTS=" -O- --header=Content-Type:application/json --post-data="
ANALYTICS_URL="http://analytics.kuzzle.io/"
GITTER_URL="https://gitter.im/kuzzleio/kuzzle"
SUPPORT_MAIL="support@kuzzle.io"
COMPOSE_YML_URL="https://kuzzle.io/docker-compose.yml"
COMPOSE_YML_PATH=$KUZZLE_DIR/docker-compose.yml
INSTALL_KUZZLE_WITHOUT_DOCKER_URL="https://docs.kuzzle.io/guide/essentials/installing-kuzzle/#manually"
MIN_DOCKER_VER=1.12.0
MIN_MAX_MAP_COUNT=262144
CONNECT_TO_KUZZLE_MAX_RETRY=30
CONNECT_TO_KUZZLE_WAIT_TIME_BETWEEN_RETRY=2 # in seconds
DOWNLOAD_DOCKER_COMPOSE_YML_MAX_RETRY=3
DOWNLOAD_DOCKER_COMPOSE_RETRY_WAIT_TIME=1 # in seconds
OS=""
KUZZLE_ADMIN_CONSOLE_ARCHIVE="kuzzle-admin-console.tar.gz"
KUZZLE_ADMIN_CONSOLE_URL="dl.kuzzle.io/"$KUZZLE_ADMIN_CONSOLE_ARCHIVE
KUZZLE_ADMIN_CONSOLE_PATH=$KUZZLE_DIR/$KUZZLE_ADMIN_CONSOLE_ARCHIVE

# Errors return status
NO_INTERNET=42
NO_DOWNLOAD_MANAGER=43
NO_DOCKER=44
NO_DOCKER_COMPOSE=45
DOCKER_VERSION_MISMATCH=46
MIN_MAX_MAP_COUNT_MISMATCH=47
ERROR_DOWNLOAD_DOCKER_COMPOSE=48
KUZZLE_NOT_RUNNING_AFTER_INSTALL=49


# list of colors
# see if it supports colors...
NCOLORS=$(tput colors)
if [ "$NCOLORS" -gt 0 ]; then
  BOLD=$(tput bold)
  RED=$(tput setaf 1)
  BLUE=$(tput setaf 4)
  NORMAL=$(tput sgr0)
  GREEN="$(tput setaf 2)"  
fi

# Create kuzzle workspace directory
if [ ! -d $KUZZLE_DIR ]; then
  mkdir $KUZZLE_DIR;
fi

os_lookup() {
  OSTYPE=$(uname)
  case "$OSTYPE" in
    "Darwin")
    {
        OS="OSX"
    } ;;    
    "Linux")
    {
        # If available, use LSB to identify distribution
        if [ -f /etc/lsb-release -o -d /etc/lsb-release.d ]; then
            DISTRO=$(awk -F= '/^NAME/{print $2}' /etc/os-release)
        else
            DISTRO=$(ls -d /etc/[A-Za-z]*[_-][rv]e[lr]* | grep -v "lsb" | cut -d'/' -f3 | cut -d'-' -f1 | cut -d'_' -f1)
        fi
        OS=$(echo $DISTRO | tr 'a-z' 'A-Z' | tr -d '"')
    } ;;
    *) 
    {
        OS=$OSTYPE
    } ;;
  esac
}

command_exists() {
  command -v "$1" > /dev/null 2>&1
}

set_download_manager() {
  if command_exists curl; then
    KUZZLE_DOWNLOAD_MANAGER="$(command -v curl) "$CURL_OPTS
    KUZZLE_PUSH_ANALYTICS="$(command -v curl) "$CURL_PUSH_OPTS" "
    KUZZLE_CHECK_DOCKER_COMPOSE_YML_HTTP_STATUS_CODE="$KUZZLE_DOWNLOAD_MANAGER -w %{http_code} $COMPOSE_YML_URL -o /dev/null"
    KUZZLE_CHECK_INTERNET_ACCESS=$KUZZLE_CHECK_DOCKER_COMPOSE_YML_HTTP_STATUS_CODE
    KUZZLE_CHECK_CONNECTIVITY_CMD="$(command -v curl) -o /dev/null http://localhost:7512"
    return 0
  elif command_exists wget; then
    KUZZLE_DOWNLOAD_MANAGER="$(command -v wget) "$WGET_OPTS
    KUZZLE_PUSH_ANALYTICS="$(command -v wget)"$WGET_PUSH_OPTS
    KUZZLE_CHECK_DOCKER_COMPOSE_YML_HTTP_STATUS_CODE="$KUZZLE_DOWNLOAD_MANAGER --server-response $COMPOSE_YML_URL 2>&1 | awk '/^  HTTP/{print \$2}' | tail -n 1"
    KUZZLE_CHECK_INTERNET_ACCESS="wget -o /dev/null kuzzle.io"
    KUZZLE_CHECK_CONNECTIVITY_CMD="$(command -v wget) --tries 1 -o /dev/null http://localhost:7512"
    return 0
  fi
  >&2 echo $RED"This script needs curl or wget installed."
  >&2 echo "Please install either one."$NORMAL
  exit $NO_DOWNLOAD_MANAGER
}

vercomp () {
  if [[ $1 == $2 ]]
  then
    return 0
  fi
  local IFS=.
  local i ver1=($1) ver2=($2)
  # fill empty fields in ver1 with zeros
  for ((i=${#ver1[@]}; i<${#ver2[@]}; i++))
  do
    ver1[i]=0
  done
  for ((i=0; i<${#ver1[@]}; i++))
  do
    if [[ -z ${ver2[i]} ]]
    then
      # fill empty fields in ver2 with zeros
      ver2[i]=0
    fi
    if ((10#${ver1[i]} > 10#${ver2[i]}))
    then
      return 0
    fi
    if ((10#${ver1[i]} < 10#${ver2[i]}))
    then
      return 1
    fi
  done
  return 0
}

prerequisite() {
  local ERROR=0

  # Check internet connection
  echo
  echo "Checking internet access..."
  $(eval "$KUZZLE_CHECK_INTERNET_ACCESS") &> /dev/null
  echo $KUZZLE_CHECK_INTERNET_ACCESS
  echo $?
  if [ $? -ne 0 ]; then
    <&2 echo $RED"No internet connection. Please ensure you have internet access."$NORMAL
    exit $NO_INTERNET
  fi

  # Check if docker is installed
  if ! command_exists docker; then
    >&2 echo $RED"You need docker to be able to run Kuzzle from this setup. Please install it and re-run this script"$NORMAL
    >&2 echo "If you want to install Kuzzle without docker please see $INSTALL_KUZZLE_WITHOUT_DOCKER_URL"
    >&2 echo "Once Docker is installed you will need to start it."$NORMAL
    $KUZZLE_PUSH_ANALYTICS'{"type": "missing-docker", "uid": "'$ANALYTICS_UUID'", "os": "'$OS'"}' $ANALYTICS_URL &> /dev/null
    exit $NO_DOCKER
  fi

  # Check if docker-compose is installed
  if ! command_exists docker-compose; then
    >&2 echo $RED"You need docker-compose to be able to run Kuzzle from this setup. Please install it and re-run this script"$NORMAL
    >&2 echo "If you want to install Kuzzle without docker please see $INSTALL_KUZZLE_WITHOUT_DOCKER_URL"$NORMAL
    $KUZZLE_PUSH_ANALYTICS'{"type": "missing-docker-compose", "uid": "'$ANALYTICS_UUID'", "os": "'$OS'"}' $ANALYTICS_URL &> /dev/null    
    exit $NO_DOCKER_COMPOSE
  fi

  # Check if docker version is at least $MIN_DOCKER_VER
  vercomp $(docker -v | sed 's/[^0-9.]*\([0-9.]*\).*/\1/') $MIN_DOCKER_VER
  if [ $? -ne 0 ]; then
    >&2 echo $RED"You need docker version to be at least $MIN_DOCKER_VER"$NORMAL
    $KUZZLE_PUSH_ANALYTICS'{"type": "docker-version-mismatch", "uid": "'$ANALYTICS_UUID'", "os": "'$OS'"}' $ANALYTICS_URL &> /dev/null    
    exit $DOCKER_VERSION_MISMATCH
  fi

  # Check of vm.max_map_count is at least $MIN_MAX_MAP_COUNT
  VM_MAX_MAP_COUNT=$(sysctl -n vm.max_map_count)
  if [ -z "${VM_MAX_MAP_COUNT}" ] || [ ${VM_MAX_MAP_COUNT} -lt $MIN_MAX_MAP_COUNT ]; then
    >&2 echo
    >&2 echo $RED"The current value of the kernel configuration variable vm.max_map_count (${VM_MAX_MAP_COUNT})"
    >&2 echo "is lower than the required one ($MIN_MAX_MAP_COUNT+)."
    >&2 echo "In order to make ElasticSearch working please set it by using on root: (more at https://www.elastic.co/guide/en/elasticsearch/reference/5.x/vm-max-map-count.html)"
    >&2 echo $BLUE$BOLD"sysctl -w vm.max_map_count=$MIN_MAX_MAP_COUNT"
    >&2 echo $RED"If you want to persist it please edit the $BLUE$BOLD/etc/sysctl.conf$NORMAL$RED file"
    >&2 echo "and add $BLUE$BOLD vm.max_map_count=$MIN_MAX_MAP_COUNT$NORMAL$RED in it."$NORMAL
    $KUZZLE_PUSH_ANALYTICS'{"type": "wrong-max_map_count", "uid": "'$ANALYTICS_UUID'", "os": "'$OS'"}' $ANALYTICS_URL &> /dev/null    
    exit $MIN_MAX_MAP_COUNT_MISMATCH
  fi
}

download_docker_compose_yml() {
  local RETRY=0

  echo 
  echo $BLUE"Downloading Kuzzle docker-compose.yml file..."$NORMAL

  TEST=$(eval "$KUZZLE_CHECK_DOCKER_COMPOSE_YML_HTTP_STATUS_CODE")
  while [ $TEST -ne 200 ];
    do
      if [ $RETRY -gt $DOWNLOAD_DOCKER_COMPOSE_YML_MAX_RETRY ]; then
        >&2 echo $RED"Cannot download $COMPOSE_YML_URL (HTTP ERROR CODE: $TEST)"
        >&2 echo "If the problem persist contact us at $SUPPORT_MAIL or on gitter at $GITTER_URL."$NORMAL
        $KUZZLE_PUSH_ANALYTICS'{"type": "error-download-dockercomposeyml", "uid": "'$ANALYTICS_UUID'", "os": "'$OS'"}' $ANALYTICS_URL &> /dev/null
        exit $ERROR_DOWNLOAD_DOCKER_COMPOSE
      fi
      RETRY=$(expr $RETRY + 1)
      sleep $DOWNLOAD_DOCKER_COMPOSE_RETRY_WAIT_TIME
      TEST=$(eval "$KUZZLE_CHECK_DOCKER_COMPOSE_YML_HTTP_STATUS_CODE")
    done
  $KUZZLE_DOWNLOAD_MANAGER $COMPOSE_YML_URL > $COMPOSE_YML_PATH
  echo $GREEN"Downloaded"$NORMAL
  echo
}

pull_kuzzle() {
  echo $BLUE"Pulling latest version of Kuzzle from dockerhub"$NORMAL
  echo
  $KUZZLE_PUSH_ANALYTICS'{"type": "pulling-latest-containers", "uid": "'$ANALYTICS_UUID'", "os": "'$OS'"}' $ANALYTICS_URL &> /dev/null
  $(command -v docker-compose) -f $COMPOSE_YML_PATH pull
  RET=$?
  if [ $RET -ne 0 ]; then
    $KUZZLE_PUSH_ANALYTICS'{"type": "pull-failed", "uid": "'$ANALYTICS_UUID'", "os": "'$OS'"}' $ANALYTICS_URL &> /dev/null
    >&2 echo
    >&2 echo $RED"Pull failed. Please ensure your docker is running."
    >&2 echo "You can try and run docker with service docker start or dockerd."
    >&2 echo "To know more please refer to https://docs.docker.com/config/daemon"$NORMAL
    exit $RET
  fi
  echo $GREEN"Pulled"$NORMAL
  $KUZZLE_PUSH_ANALYTICS'{"type": "pulled-latest-containers", "uid": "'$ANALYTICS_UUID'", "os": "'$OS'"}' $ANALYTICS_URL &> /dev/null  
}

run_kuzzle() {
  $KUZZLE_PUSH_ANALYTICS'{"type": "starting-kuzzle", "uid": "'$ANALYTICS_UUID'", "os": "'$OS'"}' $ANALYTICS_URL &> /dev/null      
  echo
  echo $BLUE"Starting Kuzzle..."$NORMAL
  $(command -v docker-compose) -f $COMPOSE_YML_PATH up -d
}

check_kuzzle() {
  local RETRY=0

  echo -n $BLUE"Checking if Kuzzle is running (timeout "
  echo -n $(expr $CONNECT_TO_KUZZLE_WAIT_TIME_BETWEEN_RETRY \* $CONNECT_TO_KUZZLE_MAX_RETRY)
  echo " seconds)"$NORMAL
  while ! $KUZZLE_CHECK_CONNECTIVITY_CMD &> /dev/null
    do
    if [ $RETRY -gt $CONNECT_TO_KUZZLE_MAX_RETRY ]; then
      $KUZZLE_PUSH_ANALYTICS'{"type": "kuzzle-failed-running", "uid": "'$ANALYTICS_UUID'", "os": "'$OS'"}' $ANALYTICS_URL &> /dev/null    
      >&2 echo
      >&2 echo $RED"Ooops! Something went wrong."
      >&2 echo "Kuzzle does not seem to respond as expected to requests to"
      >&2 echo "http://localhost:7512"$NORMAL
      >&2 echo
      echo "Feel free to get in touch with the support team by sending"
      echo "a mail to $SUPPORT_MAIL or by joining the chat room on"
      echo "Gitter at $GITTER_URL - We'll be glad to help you."

      exit $KUZZLE_NOT_RUNNING_AFTER_INSTALL
    fi
      echo -n "."
      sleep 2
      RETRY=$(expr $RETRY + 1)
    done
  $KUZZLE_PUSH_ANALYTICS'{"type": "kuzzle-running", "uid": "'$ANALYTICS_UUID'", "os": "'$OS'"}' $ANALYTICS_URL &> /dev/null
  echo $GREEN"Kuzzle is now running"$NORMAL
  echo
}

get_admin_console() {
  while [[ "$INSTALL_ADMIN_CONSOLE" != [yYnN] ]]
  do
    echo
    echo "Kuzzle Admin Console is a stateless, lightweight Kuzzle client living on a web browser."
    echo "An up-to-date version is freely available http://kuzzle-backoffice.netlify.com, and you may also execute it from a local location"
    echo "(this might be useful if your servers don't have an open connection to the Internet)."
    echo "Both versions will open a point-to-point connection between your web browser and a Kuzzle server and data will never be transmitted to anyone."
    echo "Do you want to install the offline Kuzzle Admin Console? (y/N)"
    echo -n "> "
    read installDL trash
    case $INSTALL_ADMIN_CONSOLE in
      [yY])
         $KUZZLE_DOWNLOAD_MANAGER $KUZZLE_ADMIN_CONSOLE_URL > $KUZZLE_ADMIN_CONSOLE_PATH
         cd $KUZZLE_ADMIN_CONSOLE_PATH
         tar -xvf $KUZZLE_ADMIN_CONSOLE_ARCHIVE
         mv dist kuzzle-admin-console
         echo "You can now access the Kuzzle Admin Console locally by going to your browser at file:///"$(pwd)"/kuzzle/kuzzle-admin-console"
        ;;
      [nN] | '')
        return 0
        ;;
      *)
        echo
        >&2 $RED"Please, answer Y or N."$NORMAL
        ;;
    esac
  done
}

the_end() {
  echo $BLUE"You can see the logs of the Kuzzle stack by typing:"$NORMAL
  echo " docker-compose -f $COMPOSE_YML_PATH logs -f"
  echo $BLUE"You can stop Kuzzle by typing:"$NORMAL
  echo " docker-compose -f $COMPOSE_YML_PATH stop"
  echo $BLUE"You can start Kuzzle by typing:"$NORMAL
  echo " docker-compose -f $COMPOSE_YML_PATH up -d"
  echo $BLUE"You can restart Kuzzle by typing:"$NORMAL
  echo " docker-compose -f $COMPOSE_YML_PATH restart"
  echo
  echo "You can read the docs at http://docs.kuzzle.io/"
}

######### MAIN

if [ "$1" == "--help" ]; then
  echo "--help     show this help"
  echo "--no-run   only install Kuzzle, don't run it"
  exit 1
fi

if [ ! -f "${KUZZLE_DIR}/uid" ]; then
  echo $(LC_CTYPE=C tr -dc A-Fa-f0-9 < /dev/urandom | fold -w 64 | head -n 1) > "${KUZZLE_DIR}/.uid"
  FIRST_INSTALL=1
fi

ANALYTICS_UUID=$(cat "${KUZZLE_DIR}/.uid")

echo
echo "# Kuzzle Setup"
echo "  ============"
echo
echo "This script will help you running Kuzzle and installing"
echo "all the necessary dependencies."
echo
echo "* You can refer to http://docs.kuzzle.io/ if you need better"
echo "  understanding of the installation process."
echo "* Feel free to join us on Gitter at $GITTER_URL if you need help."
echo

echo "                                ███████████████████████"
echo " ██████████████████████████████████████████████████████"
echo " █                            ▐█     ███  █████     ███"
echo " █    █  █   █   █  █████    ▐██████ ███  █████  ██████"
echo " █    █ █    █   █      █    ██████ ████  █████    ████"
echo " █    ██     █   █     █    ▐█████ █████  █████  ██████"
echo " █    █ █    █   █    █     █████ ██████  █████  ██████"
echo " █    █ █    █   █   █     ▐████     ███     ██     ███"
echo " █    █  █    ███   █████  ████████████████████████████"
echo " █                        ▐████████████████████████████"
echo " ██████████████████████████"

set_download_manager
os_lookup

$KUZZLE_PUSH_ANALYTICS'{"type": "start-setup", "uid": "'$ANALYTICS_UUID'", "os": "'$OS'"}' $ANALYTICS_URL &> /dev/null

prerequisite

trap abort_setup INT

# send abort-setup event to analytics on SIGINT
abort_setup() {
  $KUZZLE_PUSH_ANALYTICS'{"type": "abort-setup", "uid": "'$ANALYTICS_UUID'", "os": "'$OS'"}' $ANALYTICS_URL &> /dev/null
  exit 1
}


download_docker_compose_yml
pull_kuzzle
if [ "$1" != "--no-run" ]; then
  run_kuzzle
  check_kuzzle
fi
echo $GREEN"Kuzzle successfully installed"$NORMAL
echo

get_admin_console
the_end

exit 0

########## END OF MAIN
