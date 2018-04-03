#!/bin/bash

# list of colors
# check if stdout is a terminal...
if test -t 1; then
  # see if it supports colors...
  ncolors=$(tput colors)
  if test -n "$ncolors" && test $ncolors -ge 8; then
    BOLD=$(tput bold)
    RED="$(tput setaf 1)"
    BLUE="$(tput setaf 4)"
    GREEN="$(tput setaf 2)"
    YELLOW="$(tput setaf 3)"
    NORMAL="$(tput sgr0)"
  fi
fi

CURRENT_OS=Unknown
OS_IS_SUPPORTED=0
DOCKER_COMPOSE_BIN=/usr/local/bin/docker-compose
ANALYTICS_URL="http://analytics.kuzzle.io/"
GITTER_URL="https://gitter.im/kuzzleio/kuzzle"
COMPOSER_YML_URL="http://kuzzle.io/docker-compose.yml"
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

# Errors return status
NO_INTERNET=42
NO_DOWNLOAD_MANAGER=43
MISSING_DEPENDENCY=44
ERROR_DOWNLOAD_DOCKER_COMPOSE=45
KUZZLE_NOT_RUNNING_AFTER_INSTALL=46

if [ ! -d $KUZZLE_DIR ]; then
  mkdir $KUZZLE_DIR;
fi

if [ ! -f "${KUZZLE_DIR}/uid" ]; then
  echo $(LC_CTYPE=C tr -dc A-Fa-f0-9 < /dev/urandom | fold -w ${1:-64} | head -n 1) > "${KUZZLE_DIR}/uid"
  FIRST_INSTALL=1
fi

UUID=$(cat "${KUZZLE_DIR}/uid")

trap abortSetup INT

function abortSetup() {
  if [ ! -z $DL_BIN ]; then
    $DL_BIN $UL_OPTS '{"type": "abort-setup", "uid": "'$UUID'"}' $ANALYTICS_URL &> /dev/null
  fi
  exit 1
}

# Output a text with the selected color (reinit to normal at the end)
write() {
  echo -e " $1$2" "$NORMAL"
}

writeBold() {
  echo -e "${BOLD} $1$2" "$NORMAL"
}

promptBold() {
  echo -n -e "${BOLD} $1$2" "$NORMAL"
}

commandExists() {
  command -v "$@" > /dev/null 2>&1
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
      return 1
    fi
    if ((10#${ver1[i]} < 10#${ver2[i]}))
    then
      return 2
    fi
  done
  return 0
}

check_internet_acess() {
  echo
  echo "Checking internet access..."
  $KUZZLE_CHECK_INTERNET_ACCESS &> /dev/null
  if [ $? -ne 0 ]; then
    <&2 echo $RED"No internet connection. Please ensure you have internet access."$NORMAL
    exit $NO_INTERNET
  fi
}

prerequisite() {
  local ERROR=0

  # Check if docker is installed
  if ! command_exists docker; then
    >&2 echo $RED"You need docker to be able to run Kuzzle from this setup. Please install it and re-run this script."
    >&2 echo "Please refer to https://docs.docker.com/install to know more about how to install docker."$NORMAL
    >&2 echo "If you want to install Kuzzle without docker please see $INSTALL_KUZZLE_WITHOUT_DOCKER_URL"
    >&2 echo "Once Docker is installed you will need to start it."$NORMAL
    $KUZZLE_PUSH_ANALYTICS'{"type": "missing-docker", "uid": "'$ANALYTICS_UUID'", "os": "'$OS'"}' $ANALYTICS_URL &> /dev/null
    ERROR=$MISSING_DEPENDENCY
  fi

  # Check if docker-compose is installed
  if ! command_exists docker-compose; then
    >&2 echo $RED"You need docker-compose to be able to run Kuzzle from this setup. Please install it and re-run this script"$NORMAL
    >&2 echo "If you want to install Kuzzle without docker please see $INSTALL_KUZZLE_WITHOUT_DOCKER_URL"$NORMAL
    $KUZZLE_PUSH_ANALYTICS'{"type": "missing-docker-compose", "uid": "'$ANALYTICS_UUID'", "os": "'$OS'"}' $ANALYTICS_URL &> /dev/null    
    ERROR=$MISSING_DEPENDENCY
  fi
}

  # Check if docker version is at least $MIN_DOCKER_VER
  if [ $ERROR -eq 0 ]; then
    vercomp $(docker -v | sed 's/[^0-9.]*\([0-9.]*\).*/\1/') $MIN_DOCKER_VER
    if [ $? -ne 0 ]; then
      >&2 echo $RED"You need docker version to be at least $MIN_DOCKER_VER"$NORMAL
      $KUZZLE_PUSH_ANALYTICS'{"type": "docker-version-mismatch", "uid": "'$ANALYTICS_UUID'", "os": "'$OS'"}' $ANALYTICS_URL &> /dev/null    
      ERROR=$MISSING_DEPENDENCY
    fi
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
    ERROR=$MISSING_DEPENDENCY
  fi

  if [ $ERROR -ne 0 ]; then
    exit $ERROR
  fi
}

failDL() {
  echo
  writeBold "$YELLOW" "[✖] curl or wget are necessary to install Kuzzle. However,"
  writeBold "$YELLOW" "     none of them seems to be available on your system."
  write               "     Please install curl or wget and re-run this script."
  echo
  exit 9
}

installDocker() {
  writeBold "    This script can install Docker for you, otherwise you can do it manually."
  write     "    More information at https://docs.docker.com/engine/installation/"
  while [[ "$installDocker" != [yYnN] ]]
  do
    echo
    writeBold "[❓] Do you want to install Docker now? (y/N)"
    echo -n "> "
    read installDocker trash
    echo
    case $installDocker in
      [yY])
        exitIfNotRoot
        if [ -z $DL_BIN ]; then
          failDL
        else
          writeBold "[ℹ] Installing Docker..."
          $DL_BIN $DL_OPTS https://get.docker.com/ | sh
          writeBold "$GREEN" "[✔] Docker successfully installed."
        fi
        ;;
      [nN] | '')
        writeBold "$BLUE" "Ok. Please install Docker and re-run this script. "
        echo
        exit 0
        ;;
      *)
        writeBold "$RED" "[✖] Please, answer Y or N."
        ;;
    esac
  done
}

installDockerCompose() {
  writeBold "    This script can install Docker Compose for you, otherwise you can do it manually."
  write     "    More information at https://docs.docker.com/compose/install/"
  while [[ "$installDockerCompose" != [yYnN] ]]
  do
    echo
    writeBold "[❓] Do you want to install Docker Compose now? (y/N)"
    echo -n "> "
    read installDockerCompose trash
    echo
    case "$installDockerCompose" in
      [yY])
        exitIfNotRoot
        if [ -z $DL_BIN ]; then
          failDL
        else
          writeBold "Installing Docker Compose..."
          $DL_BIN $DL_OPTS "https://github.com/docker/compose/releases/download/1.12.0/docker-compose-$(uname -s)-$(uname -m)" > $DOCKER_COMPOSE_BIN
          chmod +x $DOCKER_COMPOSE_BIN
          writeBold "$GREEN" "[✔] Docker Compose successfully installed."
        fi
        ;;
      [nN] | '')
        writeBold "$BLUE" "Ok. Please install Docker Compose and re-run this script."
        echo
        exit 0
        ;;
      *)
        writeBold "$RED" "[✖] Please, answer Y or N."
        ;;
    esac
  done
}

setupMapCount() {
  SYSCTL_CONF_FILE=/etc/sysctl.conf
  writeBold "    This script can set it automatically or you can do it manually."
  write     "    More information at https://www.elastic.co/guide/en/elasticsearch/reference/5.x/vm-max-map-count.html"
  while [[ "$setVmParam" != [yYnN] ]]
  do
    echo
    writeBold "[❓] Do you want to set the vm.max_map_count now? (y/N) "
    echo -n "> "
    read setVmParam trash
    case "$setVmParam" in
      [yY])
        echo
        writeBold "Setting kernel variable vm.max_map_count to $REQUIRED_MAP_COUNT..."
        sysctl -w vm.max_map_count=$REQUIRED_MAP_COUNT
        if [ -z "$MAP_COUNT" ]; then
          echo "vm.max_map_count=$REQUIRED_MAP_COUNT" >> $SYSCTL_CONF_FILE
        else
          sed 's/vm.max_map_count=.+/vm.max_map_count=$REQUIRED_MAP_COUNT/g' > ${TMPDIR-/tmp}/sysctl.tmp
          mv ${TMPDIR-/tmp}/sysctl.tmp $SYSCTL_CONF_FILE
        fi
        writeBold "$GREEN" "[✔] Kernel variable successfully set."
        ;;
      [nN] | '')
        echo
        writeBold "$BLUE" "Ok. Please set the kernel variable and re-run this script."
        echo
        exit 0
        ;;
      *)
      echo
      writeBold "$RED" "[✖] Please, answer Y or N."
      ;;
    esac
  done
}

collectPersonalData() {
  echo
  while [[ "$purpose" != [012345] ]]
  do
    writeBold "[❓] What are you going to use Kuzzle for?"
    write     "    1) IoT"
    write     "    2) Web"
    write     "    3) Mobile"
    write     "    4) Machine-to-machine"
    write     "    5) Other"
    write     "    0) Stop bugging me"
    echo -n "> "
    read purpose trash
  done

  case "$purpose" in
    0) purpose="Stop bugging me" ;;
    1) purpose="IoT" ;;
    2) purpose="Web" ;;
    3) purpose="Mobile" ;;
    4) purpose="Machine-to-machine" ;;
    5) purpose="Other" ;;
  esac
  echo
  writeBold "[❓] Would you like us to reach you to have your feedback on Kuzzle? (y/N)"
  write     "    We will be really discreet (and this will help us a lot improving Kuzzle)"
  echo -n "> "
  while [[ "$agreeOnPersonalData" != [yYnN] ]]
  do
    read agreeOnPersonalData trash
    case "$agreeOnPersonalData" in
      [yY])
        echo
        writeBold "[❓] What's your email address?${NORMAL} (press Enter to skip)"
        echo -n "> "
        read email trash
        echo
        writeBold "[❓] What's your full name?${NORMAL} (press Enter to skip)"
        echo -n "> "
        read name
        echo
        writeBold "$GREEN" "[✔] Thanks a lot!"
        echo
        ;;
      [nN] | '')
        writeBold "$BLUE" "Ok."
        agreeOnPersonalData="n"
        echo
        ;;
      *)
        writeBold "$RED" "[✖] Please, answer Y or N."
        ;;
    esac
  done
  $DL_BIN $UL_OPTS '{"type": "collected-data", "uid": "'$UUID'", "email": "'$email'", "name": "'"$name"'", "purpose": "'"$purpose"'", "os": "'$CURRENT_OS'"}' $ANALYTICS_URL &> /dev/null
}

startKuzzle() {
  echo
  if [ ! -f $COMPOSER_YML_PATH ]; then
    $DL_BIN $UL_OPTS '{"type": "first-download", "uid": "'$UUID'"}' $ANALYTICS_URL &> /dev/null
  fi

  if [ -z $DL_BIN ]; then
    failDL
  else
    write "[ℹ] Downloading Kuzzle launch file..."
    $DL_BIN $DL_OPTS $COMPOSER_YML_URL > $COMPOSER_YML_PATH
  fi

  writeBold "$GREEN" "[✔] The Kuzzle launch file has been successfully downloaded."

  echo
  writeBold          "    This script can launch Kuzzle automatically or you can do it"
  writeBold          "    manually using Docker Compose."
  write              "    To manually launch Kuzzle you can type the following command:"
  write              "    docker-compose -f $COMPOSER_YML_PATH up"

  echo
  writeBold "[❓] Do you want to pull the latest version of Kuzzle now? (y/N)"
  write      "    If you never have started kuzzle, it will be pulled automatically"
  echo -n "> "
  read pullLatest trash
  case "$pullLatest" in
    [yY])
      echo
      write "[ℹ] Pulling latest version Kuzzle..."
      $DL_BIN $UL_OPTS '{"type": "pulling-latest-containers", "uid": "'$UUID'"}' $ANALYTICS_URL &> /dev/null
      $(command -v docker-compose) -f $COMPOSER_YML_PATH pull &> /dev/null
      writeBold "$GREEN" "[✔] Done."
      $DL_BIN $UL_OPTS '{"type": "pulled-latest-containers", "uid": "'$UUID'"}' $ANALYTICS_URL &> /dev/null
      ;;
    *)
      writeBold "$BLUE" "Ok."
      ;;
  esac

  while [[ "$launchTheStack" != [yYnN] ]]; do
    echo
    writeBold "[❓] Do you want to automatically start Kuzzle now? (y/N) "
    echo -n "> "
    read launchTheStack trash
    case "$launchTheStack" in
      [yY])
        echo
        write "[ℹ] Starting Kuzzle..."
        $(command -v docker-compose) -f $COMPOSER_YML_PATH up -d &> /dev/null
        $DL_BIN $UL_OPTS '{"type": "starting-kuzzle", "uid": "'$UUID'"}' $ANALYTICS_URL &> /dev/null
        isKuzzleRunning
        ;;
      [nN] | '')
        echo
        writeBold "$BLUE" "Ok."
        launchTheStack=n
        ;;
      *)
        echo
        writeBold "$RED" "[✖] Please, answer Y or N."
        ;;
    esac
  done
}

isKuzzleRunning() {
  write "[ℹ] Checking that everything is running"

  while ! curl -f -s -o /dev/null "http://localhost:7512"
  do
    echo -n "."
    sleep 2
  done
  echo
  CHECK_KUZZLE_RUNNING=$(curl -s -S -I -XGET http://localhost:7512 | grep HTTP | perl -nle 'm/HTTP\/1\.1 (\d\d\d)/;print $1')
  if [ "$CHECK_KUZZLE_RUNNING" != "200" ]; then
    echo
    writeBold "$RED" "[✖] Ooops! Something went wrong."
    write            "    Kuzzle does not seem to respond as expected to requests to"
    write            "    http://localhost:7511"
    echo
    writeBold "$YELLOW" "Feel free to get in touch with the support team by sending"
    writeBold "$YELLOW" "a mail to $SUPPORT_MAIL or by joining the chat room on"
    writeBold "$YELLOW" "Gitter at $GITTER_URL - We'll be glad to help you."
    echo
    write     "Sorry for the inconvenience."
    echo
    $DL_BIN $UL_OPTS '{"type": "kuzzle-failed-running", "uid": "'$UUID'"}' $ANALYTICS_URL &> /dev/null
    exit 8
  else
    writeBold "$GREEN" "[✔] Kuzzle is running!"
    $DL_BIN $UL_OPTS '{"type": "kuzzle-running", "uid": "'$UUID'"}' $ANALYTICS_URL &> /dev/null
  fi
}

shortHelp() {
  echo
  writeBold "* You can open this short help by calling ./setup.sh --help"
  writeBold "* You can start Kuzzle by typing:"
  write "  docker-compose -f $COMPOSER_YML_PATH up -d"
  writeBold "* You can see the logs of the Kuzzle stack by typing:"
  write "  docker-compose -f $COMPOSER_YML_PATH logs -f"
  writeBold "* You can check if everything is working by typing:"
  write "  curl -XGET http://localhost:7512/"
  writeBold "* You can stop Kuzzle by typing:"
  write "  docker-compose -f $COMPOSER_YML_PATH stop"
  writeBold "* You can restart Kuzzle by typing:"
  write "  docker-compose -f $COMPOSER_YML_PATH restart"
  writeBold "* You can read the docs at http://docs.kuzzle.io/"
  echo
}

# Main execution routine
# ===========================

if [ "$1" == "--help" ]; then
  echo
  writeBold "# Kuzzle short help"
  writeBold "  ================="
  shortHelp
  exit 0
fi

clear
echo
writeBold "# Kuzzle Setup"
writeBold "  ============"
echo
writeBold "This script will help you launching Kuzzle and installing"
writeBold "all the necessary dependencies."
echo
write     "* You can refer to http://docs.kuzzle.io/ if you need better"
write     "  understanding of the installation process."
write     "* Feel free to join us on Gitter at $GITTER_URL"
write     "  if you need help."
echo
promptBold "$BLUE" "Press Enter to start."
read start

echo
writeBold "[ℹ] Checking system pre-requisites..."
echo

set_download_manager
check_internet_acess
os_lookup

write "$GREEN" "[✔] Architecture is x86_64."

CHECK_MEM=$(awk '/MemTotal/{print $2}' /proc/meminfo)
MEM_REQ=4000000
if (( "$CHECK_MEM" < "$MEM_REQ" )); then
  echo
  writeBold "$RED" "[✖] Kuzzle needs at least 4Gb of memory, which does not seem"
  writeBold "$RED" "    to be the available amount on your system (${CHECK_MEM})."
  write            "    Sorry, you cannot launch Kuzzle on this machine."
  echo
  exit 5
fi

write "$GREEN" "[✔] Available memory is at least 4Gb."

if ! commandExists curl && ! commandExists wget; then
  INSTALL_DL=1
  write "$YELLOW" "[✖] cUrl is not installed."
elif commandExists curl; then
  setDL "curl"
  write "$GREEN" "[✔] cUrl is installed."
elif commandExists wget; then
  setDL "wget"
  write "$GREEN" "[✔] Wget is installed."
fi

if ! commandExists docker; then
  write "$YELLOW" "[✖] Docker is not installed."
  INSTALL_DOCKER=1
elif [[ $? == 2 ]]; then
  MIN_DOCKER_VER=1.12.0
  dockerVersion=$(docker -v | perl -nle 'm/(\d+(\.\d*(\.\d*)?)?)/;print $1')
  vercomp ${dockerVersion} $MIN_DOCKER_VER
  write "$YELLOW" "[✖] The current version of Docker ${dockerVersion} is older"
  write "$YELLOW"  "    than the required one ($MIN_DOCKER_VER+)."
  INSTALL_DOCKER=1
elif ! $INSTALL_DOCKER && ! $(docker run hello-world &> /dev/null); then
  echo
  writeBold "$RED" "[✖] Docker does not seem to be running on your system."
  writeBold "$RED" "    Please start the Docker daemon and re-run this script"
  write            "    More information at https://docs.docker.com/engine/admin/"
  echo
  exit 5
else
  write "$GREEN" "[✔] Docker is installed and running."
fi

if ! commandExists docker-compose; then
  write "$YELLOW" "[✖] Docker Compose is not installed."
  INSTALL_DOCKER_COMPOSE=1
elif [[ $? == 2 ]]; then
  MIN_DOCKER_COMPOSE_VER=1.12.0
  dockerComposeVersion=$(docker-compose -v | perl -nle 'm/(\d+(\.\d*(\.\d*)?)?)/;print $1')
  vercomp ${dockerComposeVersion} $MIN_DOCKER_COMPOSE_VER
  write "$YELLOW" "[✖] The current version of Docker ${dockerComposeVersion} is older"
  write "$YELLOW"  "    than the required one ($MIN_DOCKER_COMPOSE_VER+)."
  INSTALL_DOCKER_COMPOSE=1
else
  write "$GREEN" "[✔] Docker Compose is installed."
fi

CHECK_MAP_COUNT=$(sysctl -a 2> /dev/null | grep vm.max_map_count | cut -d'=' -f2 | tr -d ' ')
REQUIRED_MAP_COUNT=262144
if [ -z "${CHECK_MAP_COUNT}" ] || [ ${CHECK_MAP_COUNT} -lt $REQUIRED_MAP_COUNT ]; then
  write "$YELLOW" "[✖] The current value of the kernel configuration variable vm.max_map_count (${CHECK_MAP_COUNT})"
  write "$YELLOW"  "    is lower than the required one ($REQUIRED_MAP_COUNT+)."
  SETUP_MAP_COUNT=1
else
  write "$GREEN" "[✔] vm.max_map_count is at least $REQUIRED_MAP_COUNT."
fi

if [[ "$INSTALL_DOCKER" == 1 || "$INSTALL_DOCKER_COMPOSE" == 1 || "$INSTALL_DL" == 1 || "$SETUP_MAP_COUNT" == 1 ]]; then
  echo
  writeBold          "[ℹ] Some of the requirements are not met. Let's take a look."
  promptBold "$BLUE" "    Press Enter to continue."
  read trash
  findOSType
  isOSSupported
fi

if [[ "$INSTALL_DL" == 1 ]]; then
  echo
  writeBold "$YELLOW" "[ℹ] cUrl needs to be installed."
  installDL
fi

if [[ "$INSTALL_DOCKER" == 1 ]]; then
  echo
  writeBold "$YELLOW" "[ℹ] Docker needs to be installed."
  installDocker
fi

if [[ "$INSTALL_DOCKER_COMPOSE" == 1 ]]; then
  echo
  writeBold "$YELLOW" "[ℹ] Docker Compose needs to be installed."
  installDockerCompose
fi

if [[ "$SETUP_MAP_COUNT" == 1 ]]; then
  echo
  writeBold "$YELLOW" "[ℹ] vm.max_map_count needs to be set at least to $REQUIRED_MAP_COUNT."
  setupMapCount
fi

$DL_BIN $whyUL_OPTS '{"type": "start-setup", "uid": "'$UUID'", "first-install": "'$FIRST_INSTALL'"}' $ANALYTICS_URL &> /dev/null

echo
writeBold "$GREEN" "[✔] All the requirements are met!"
writeBold          "    We are ready to install and start Kuzzle."

startKuzzle
collectPersonalData

writeBold "# Where do we go from here?"
writeBold "  ========================="
shortHelp
