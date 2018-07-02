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
CONNECT_TO_KUZZLE_MAX_RETRY=${CONNECT_TO_KUZZLE_MAX_RETRY:=30} # in seconds
CONNECT_TO_KUZZLE_WAIT_TIME_BETWEEN_RETRY=1 
DOWNLOAD_DOCKER_COMPOSE_YML_MAX_RETRY=3
DOWNLOAD_DOCKER_COMPOSE_RETRY_WAIT_TIME=1 # in seconds
OS=""
SYSTEMD_SERVICE="[Unit]\n
Description=Kuzzle Service\n
After=docker.service\n
Requires=docker.service\n
[Service]\n
Type=simple\n
WorkingDirectory=$PWD/kuzzle\n
ExecStart=$(command -v docker-compose) -f $PWD/$COMPOSE_YML_PATH up\n
ExecStop=$(command -v docker-compose) -f $PWD/$COMPOSE_YML_PATH stop\n
Restart=on-abort\n
[Install]\n
WantedBy=multi-user.target"
SCRIPT_ADD_TO_BOOT="#!/bin/bash
echo -e \"$SYSTEMD_SERVICE\" > /etc/systemd/system/kuzzle.service
systemctl enable kuzzle"
SCRIPT_REMOVE_FROM_BOOT="#!/bin/bash
systemctl disable kuzzle"

# Errors return status
NO_INTERNET=42
NO_DOWNLOAD_MANAGER=43
MISSING_DEPENDENCY=44
ERROR_DOWNLOAD_DOCKER_COMPOSE=45
KUZZLE_NOT_RUNNING_AFTER_INSTALL=46

# list of colors
# see if it supports colors...
NCOLORS=$(tput colors)
if [ $? -eq 0 ] && [ $NCOLORS -gt 0 ]; then
  BOLD=$(tput bold)
  RED=$(tput setaf 1)
  BLUE=$(tput setaf 6)
  NORMAL=$(tput sgr0)
  GREEN="$(tput setaf 2)"  
fi

# Create kuzzle workspace directory
if [ ! -d $KUZZLE_DIR ]; then
  mkdir $KUZZLE_DIR
fi

if [ ! -d $KUZZLE_DIR/script ]; then
  mkdir $KUZZLE_DIR/script
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

# Output a text with the selected color (reinit to normal at the end)
write() {
  echo -e " $1$2" "$NORMAL"
}

write_error() {
  >&2 echo $RED "$1$2" "$NORMAL" 
}

write_info() {
  echo $BLUE "$1$2" "$NORMAL"
}

write_success() {
  echo $GREEN "$1$2" "$NORMAL"
}

write_title() {
  echo -e "${BOLD} $1$2" "$NORMAL"
}

prompt_bold() {
  echo -n -e "${BOLD} $1$2" "$NORMAL"
}

command_exists() {
  command -v "$1" > /dev/null 2>&1
}

set_download_manager() {
  if command_exists curl; then
    KUZZLE_DOWNLOAD_MANAGER="$(command -v curl) "$CURL_OPTS
    KUZZLE_PUSH_ANALYTICS="$(command -v curl) "$CURL_PUSH_OPTS" "
    KUZZLE_CHECK_DOCKER_COMPOSE_YML_HTTP_STATUS_CODE="$KUZZLE_DOWNLOAD_MANAGER -w %{http_code} $COMPOSE_YML_URL -o /dev/null"
    KUZZLE_CHECK_INTERNET_ACCESS="$KUZZLE_DOWNLOAD_MANAGER -w %{http_code} google.com -o /dev/null"
    KUZZLE_CHECK_CONNECTIVITY_CMD="$(command -v curl) -o /dev/null http://localhost:7512"
    return 0
  elif command_exists wget; then
    KUZZLE_DOWNLOAD_MANAGER="$(command -v wget) "$WGET_OPTS
    KUZZLE_PUSH_ANALYTICS="$(command -v wget)"$WGET_PUSH_OPTS
    KUZZLE_CHECK_DOCKER_COMPOSE_YML_HTTP_STATUS_CODE="$KUZZLE_DOWNLOAD_MANAGER --server-response $COMPOSE_YML_URL 2>&1 | awk '/^  HTTP/{print \$2}' | tail -n 1"
    KUZZLE_CHECK_INTERNET_ACCESS="wget -o /dev/null google.com"
    KUZZLE_CHECK_CONNECTIVITY_CMD="$(command -v wget) --tries 1 -o /dev/null http://localhost:7512"
    return 0
  fi

  echo
  write_error "[✖] This script needs curl or wget installed."
  write_error "Please install either one."
  echo
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

check_internet_access() {
  echo
  write_info "[ℹ] Checking internet access..."
  $KUZZLE_CHECK_INTERNET_ACCESS &> /dev/null
  if [ $? -ne 0 ]; then
    write_error "[✖] No internet connection. Please ensure that you have internet access."
    echo
    exit $NO_INTERNET
  fi
  write_success "[✔] Ok."
}

prerequisite() {
  local ERROR=0
  echo
  write_info "[ℹ] Checking prerequisites..."
  # Check if docker is installed
  if ! command_exists docker; then
    write_error "[✖] This script requires Docker to run Kuzzle. Please install it and re-run this script."
    write_error "    Please refer to https://docs.docker.com/install for details about how to install Docker."
    write_error "    If you would like to install Kuzzle without Docker please refer to $INSTALL_KUZZLE_WITHOUT_DOCKER_URL"
    write_error "    Once Docker is installed make sure it is running before re-running this script."
    echo
    $KUZZLE_PUSH_ANALYTICS'{"type": "missing-docker", "uid": "'$ANALYTICS_UUID'", "os": "'$OS'"}' $ANALYTICS_URL &> /dev/null
    ERROR=$MISSING_DEPENDENCY
  fi

  # Check if docker-compose is installed
  if ! command_exists docker-compose; then
    write_error "[✖] This script requires Docker Compose to run Kuzzle. Please install it and re-run this script"
    write_error "    If you would like to install Kuzzle without Docker Compose please refer to $INSTALL_KUZZLE_WITHOUT_DOCKER_URL"
    echo
    $KUZZLE_PUSH_ANALYTICS'{"type": "missing-docker-compose", "uid": "'$ANALYTICS_UUID'", "os": "'$OS'"}' $ANALYTICS_URL &> /dev/null    
    ERROR=$MISSING_DEPENDENCY
  fi

  # Check if docker version is at least $MIN_DOCKER_VER
  if [ $ERROR -eq 0 ]; then
    vercomp $(docker -v | sed 's/[^0-9.]*\([0-9.]*\).*/\1/') $MIN_DOCKER_VER
    if [ $? -ne 0 ]; then
      write_error "[✖] This script requires Docker version $MIN_DOCKER_VER or higher to run Kuzzle"
      echo
      $KUZZLE_PUSH_ANALYTICS'{"type": "docker-version-mismatch", "uid": "'$ANALYTICS_UUID'", "os": "'$OS'"}' $ANALYTICS_URL &> /dev/null    
      ERROR=$MISSING_DEPENDENCY
    fi
  fi

  # Check if sysctl exists on the machine
  if [ "$OS" != "OSX" ]; then
    if ! command_exists sysctl; then
      write_error "[✖] This script needs sysctl to check that your kernel settings meet the Kuzzle requirements."
      write_error "    Please install sysctl and re-run this script."
      echo
      $KUZZLE_PUSH_ANALYTICS'{"type": "missing-sysctl", "uid": "'$ANALYTICS_UUID'", "os": "'$OS'"}' $ANALYTICS_URL &> /dev/null    
      ERROR=$MISSING_DEPENDENCY
    else
      # Check of vm.max_map_count is at least $MIN_MAX_MAP_COUNT
      VM_MAX_MAP_COUNT=$(sysctl -n vm.max_map_count)
      if [ -z "${VM_MAX_MAP_COUNT}" ] || [ ${VM_MAX_MAP_COUNT} -lt $MIN_MAX_MAP_COUNT ]; then
        write_error
        write_error "[✖] The current value of the kernel configuration variable vm.max_map_count (${VM_MAX_MAP_COUNT})"
        write_error "    is lower than that required by Elasticsearch ($MIN_MAX_MAP_COUNT+)."
        write_info  "    In order to run Kuzzle please set the required value by executing the following command (needs root access):"
        write_info $BOLD "sysctl -w vm.max_map_count=$MIN_MAX_MAP_COUNT"
        write_info  "    (more at https://www.elastic.co/guide/en/elasticsearch/reference/5.x/vm-max-map-count.html)"
        write_info  "    To make this change persistent please edit the $BLUE$BOLD/etc/sysctl.conf$NORMAL$RED file"
        write_info  "    and add this line: $BLUE$BOLD vm.max_map_count=$MIN_MAX_MAP_COUNT$NORMAL$RED"
        echo
        $KUZZLE_PUSH_ANALYTICS'{"type": "wrong-max_map_count", "uid": "'$ANALYTICS_UUID'", "os": "'$OS'"}' $ANALYTICS_URL &> /dev/null    
        ERROR=$MISSING_DEPENDENCY
      fi
    fi
  fi

  if [ $ERROR -ne 0 ]; then
    exit $ERROR
  fi

  write_success "[✔] Ok."
}

download_docker_compose_yml() {
  local RETRY=0

  echo 
  write_info "[ℹ] Downloading Kuzzle docker-compose.yml file..."

  TEST=$(eval "$KUZZLE_CHECK_DOCKER_COMPOSE_YML_HTTP_STATUS_CODE")
  while [ $TEST -ne 200 ];
    do
      if [ $RETRY -gt $DOWNLOAD_DOCKER_COMPOSE_YML_MAX_RETRY ]; then
        write_error "[✖] Cannot download $COMPOSE_YML_URL (HTTP ERROR CODE: $TEST)"
        write_error "    If the problem persists please contact us at $SUPPORT_MAIL or on gitter at $GITTER_URL."
        $KUZZLE_PUSH_ANALYTICS'{"type": "error-download-dockercomposeyml", "uid": "'$ANALYTICS_UUID'", "os": "'$OS'"}' $ANALYTICS_URL &> /dev/null
        exit $ERROR_DOWNLOAD_DOCKER_COMPOSE
      fi
      RETRY=$(expr $RETRY + 1)
      sleep $DOWNLOAD_DOCKER_COMPOSE_RETRY_WAIT_TIME
      TEST=$(eval "$KUZZLE_CHECK_DOCKER_COMPOSE_YML_HTTP_STATUS_CODE")
    done
  $KUZZLE_DOWNLOAD_MANAGER $COMPOSE_YML_URL > $COMPOSE_YML_PATH
  write_success "[✔] Downloaded."
  echo
}

pull_kuzzle() {
  write_info "[ℹ] Pulling the latest version of Kuzzle from Dockerhub..."
  $KUZZLE_PUSH_ANALYTICS'{"type": "pulling-latest-containers", "uid": "'$ANALYTICS_UUID'", "os": "'$OS'"}' $ANALYTICS_URL &> /dev/null
  $(command -v docker-compose) -f $COMPOSE_YML_PATH pull
  RET=$?
  if [ $RET -ne 0 ]; then
    $KUZZLE_PUSH_ANALYTICS'{"type": "pull-failed", "uid": "'$ANALYTICS_UUID'", "os": "'$OS'"}' $ANALYTICS_URL &> /dev/null
    echo
    write_error "[✖] The pull failed. Is Docker running?"
    write_info  "    You can try to run Docker by typing"
    write_info $BOLD "service docker start"
    write_error "    or"
    write_info $BOLD "dockerd &"
    write_error "    To learn more, refer to https://docs.docker.com/config/daemon"
    exit $RET
  fi
  write_success "[✔] Pulled."
  $KUZZLE_PUSH_ANALYTICS'{"type": "pulled-latest-containers", "uid": "'$ANALYTICS_UUID'", "os": "'$OS'"}' $ANALYTICS_URL &> /dev/null  
}

run_kuzzle() {
  $KUZZLE_PUSH_ANALYTICS'{"type": "starting-kuzzle", "uid": "'$ANALYTICS_UUID'", "os": "'$OS'"}' $ANALYTICS_URL &> /dev/null      
  echo
  write_info "[ℹ] Starting Kuzzle..."
  $(command -v docker-compose) -f $COMPOSE_YML_PATH up -d
}

check_kuzzle() {
  local RETRY=0

  echo -n $BLUE"[ℹ] Checking if Kuzzle is running (timeout "
  echo -n $(expr $CONNECT_TO_KUZZLE_MAX_RETRY)
  echo " seconds)"$NORMAL
  while ! $KUZZLE_CHECK_CONNECTIVITY_CMD &> /dev/null
    do
    if [ $RETRY -gt $CONNECT_TO_KUZZLE_MAX_RETRY ]; then
      $KUZZLE_PUSH_ANALYTICS'{"type": "kuzzle-failed-running", "uid": "'$ANALYTICS_UUID'", "os": "'$OS'"}' $ANALYTICS_URL &> /dev/null    
      >&2 echo
      write_error "[✖] Ooops! Something went wrong."
      write_error "    Kuzzle does not seem to be running"
      if [ "$OS" = "OSX" ]; then
        write_info "[i] This might be due to a configuration problem linked to Docker For Mac. Please take a look at the following issue:"
        write_info "https://stackoverflow.com/questions/41192680/update-max-map-count-for-elasticsearch-docker-container-mac-host"
      fi
      echo
      write "Please feel free to get in touch with our support team by sending"
      write "a mail to $SUPPORT_MAIL or by joining our chat room on"
      write "Gitter at $GITTER_URL - We'll be glad to help you."

      exit $KUZZLE_NOT_RUNNING_AFTER_INSTALL
    fi
      echo -n "."
      sleep 1
      RETRY=$(expr $RETRY + 1)
    done
  $KUZZLE_PUSH_ANALYTICS'{"type": "kuzzle-running", "uid": "'$ANALYTICS_UUID'", "os": "'$OS'"}' $ANALYTICS_URL &> /dev/null
  echo
  write_success "[✔] Kuzzle is now running."
  echo
}

write_scripts() {
  echo "$SCRIPT_ADD_TO_BOOT" > $KUZZLE_DIR/script/add-kuzzle-boot-systemd.sh
  chmod +x $KUZZLE_DIR/script/add-kuzzle-boot-systemd.sh
  echo "$SCRIPT_REMOVE_FROM_BOOT" > $KUZZLE_DIR/script/remove-kuzzle-boot-systemd.sh
  chmod +x $KUZZLE_DIR/script/remove-kuzzle-boot-systemd.sh
}

the_end() {
  write_info "You can see Kuzzle stack logs by typing:"
  write " docker-compose -f $COMPOSE_YML_PATH logs -f"
  write_info "You can stop Kuzzle by typing:"
  write " docker-compose -f $COMPOSE_YML_PATH stop"
  write_info "You can start Kuzzle by typing:"
  write " docker-compose -f $COMPOSE_YML_PATH up -d"
  write_info "You can restart Kuzzle by typing:"
  write " docker-compose -f $COMPOSE_YML_PATH restart"
  write
  write_info "Take a look at our docs and learn how to get started at"
  write_title "https://docs.kuzzle.io/#sdk-play-time"
}

######## MAIN

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
clear
echo
write_title "# Kuzzle Setup"
write_title "  ============"
echo
write "This script will check for all necessary prerequisites"
write "then install and run Kuzzle."
echo
write "* For more information about the installation process"
write "  please refer to http://docs.kuzzle.io/."
write "* Feel free to join us on Gitter at"
write "  $GITTER_URL if you need help."
echo

write "                                ███████████████████████"
write " ██████████████████████████████████████████████████████"
write " █                            ▐█     ███  █████     ███"
write " █    █  █   █   █  █████    ▐██████ ███  █████  ██████"
write " █    █ █    █   █      █    ██████ ████  █████    ████"
write " █    ██     █   █     █    ▐█████ █████  █████  ██████"
write " █    █ █    █   █    █     █████ ██████  █████  ██████"
write " █    █ █    █   █   █     ▐████     ███     ██     ███"
write " █    █  █    ███   █████  ████████████████████████████"
write " █                        ▐████████████████████████████"
write " ██████████████████████████"
echo
prompt_bold "[❓] Ready to install Kuzzle? (Ctrl + C to abort)"
read vazyGroNaz

set_download_manager
check_internet_access
os_lookup
write_scripts

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
echo
write_success $BOLD"[✔] Kuzzle successfully installed"
echo

the_end
echo
exit 0

########## END OF MAIN
