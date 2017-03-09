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

findOSType()
{
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
  case "$CURRENT_OS" in
    "UBUNTU" | "DEBIAN")
    {
      OS_IS_SUPPORTED=1
    } ;;
    *)
    {
      echo
      writeBold "$YELLOW" "[✖] Your OS ($CURRENT_OS) is not officially supported."
      write               "    This means we didn't thoroughly test Kuzzle on your"
      write               "    system. It is likely to work, so you may want to continue."
      OS_IS_SUPPORTED=0
      while [[ "$proceedNotSupported" != [yYnN] ]]
      do
        promptBold "[❓] Do you want to continue? (y/N)"
        read proceedNotSupported trash
        case "$proceedNotSupported" in
          [yY])
            echo
            writeBold "$GREEN" "Great! Join us on Gitter if you need help (https://gitter.im/kuzzleio/kuzzle)"
            ;;
          [nN] | '')
            if [ -n $DL_BIN ]; then
              echo
              writeBold "[❓] Would you like to be notified when your OS is supported? (y/N)"
              write      "   This will increase the chances that your OS will be supported in the future."
              read notifyTeam trash
              case "$notifyTeam" in
                [yY])
                  promptBold "[❓] Ok. What is your email address?"
                  read email trash
                  $DL_BIN $UL_OPTS '{"type": "failed-attempt", "os": "'$CURRENT_OS'", "email": "'$email'"}' $ANALYTICS_URL &> /dev/null
                  ;;
                *)
                  echo
                  writeBold "$BLUE" "Ok. We encourage you to get in touch with the team (tech@kuzzle.io)"
                  writeBold "$BLUE" "to request support for your system."
                  echo
                  ;;
              esac
              exit 2
            fi
            ;;
          *)
            echo
            writeBold "$RED" "[✖] Please, answer Y or N."
            ;;
        esac
      done
    } ;;
  esac
}

installDL() {
  echo
  writeBold "[ℹ] It is recommended to have cUrl to install Kuzzle. However it"
  writeBold "    does not seem to be installed on your system."
  while [[ "$installDL" != [yYnN] ]]
  do
    promptBold "[❓] Do you want to install cUrl automatically now? (y/N)"
    read installDL trash
    case $installDL in
      [yY])
        echo
        if commandExists apt-get; then
          apt-get -y install curl
          setDL curl
          writeBold "$GREEN" "[✔] cUrl successfully installed."
        elif commandExists yum; then
          yum install curl
          setDL curl
          writeBold "$GREEN" "[✔] cUrl successfully installed."
        else
          echo
          writeBold "$YELLOW" "[✖] Sorry, no suitable package manager found."
          echo
          exit 8
        fi
        ;;
      [nN] | '')
        echo
        writeBold "$BLUE" "Ok."
        echo
        ;;
      *)
        echo
        writeBold "$RED" "[✖] Please, answer Y or N."
        ;;
    esac
  done
}

setDL() {
  if [ "$1" == 'curl' ]; then
    DL_BIN=$(command -v curl)
    DL_OPTS="-sSL"
    UL_OPTS='-H Content-Type:application/json --data'
  elif [ "$1" == 'wget' ]; then
    DL_BIN=$(command -v wget)
    DL_OPTS="-qO-"
    UL_OPTS="--header=Content-Type:application/json --post-data="
  else
    echo
    writeBold "$RED" "[✖] something went wrong detecting the downlaoder."
    exit 10
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
    promptBold "[❓] Do you want to install Docker now? (y/N)"
    read installDocker trash
    echo
    case $installDocker in
      [yY])
        if [ -z $DL_BIN ]; then
          failDL
        else
          writeBold "[ℹ] Installing Docker..."
          $DL_BIN $DL_OPTS https://get.docker.com/ | sh &> /dev/null
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
    promptBold "[❓] Do you want to install Docker Compose now? (y/N)"
    read installDockerCompose trash
    echo
    case "$installDockerCompose" in
      [yY])
        if [ -z $DL_BIN ]; then
          failDL
        else
          writeBold "Installing Docker Compose..."
          $DL_BIN $DL_OPTS "https://github.com/docker/compose/releases/download/1.10.0/docker-compose-$(uname -s)-$(uname -m)" > $DOCKER_COMPOSE_BIN
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
    promptBold "[❓] Do you want to set the vm.max_map_count now? (y/N) "
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
  writeBold "[❓] Would you agree on letting us know a little bit about you? (y/N)"
  write     "    We'd like to know your name and email, your OS type and why"
  write     "    you're interested in Kuzzle."
  while [[ "$agreeOnPersonalData" != [yYnN] ]]
  do
    read agreeOnPersonalData trash
    echo
    case "$agreeOnPersonalData" in
      [yY])
        promptBold "    What's your email address?${NORMAL} (press Enter to skip)"
        read email trash
        promptBold "    What's your full name?${NORMAL} (press Enter to skip)"
        read firstName lastName otherName yetAnotherName trash
        promptBold "    What do you plan to use Kuzzle for?${NORMAL} (press Enter to skip)"
        read purpose
        $DL_BIN $UL_OPTS '{"type": "collected-data", "email": "'$email'", "name": "'"$firstName $lastName $otherName $yetAnotherName"'", "purpose": "'"$purpose"'", "os": "'$CURRENT_OS'"}' $ANALYTICS_URL # &> /dev/null
        echo
        writeBold "$GREEN" "[✔] Thank you!"
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
}

startKuzzle() {
  composerYMLURL="http://kuzzle.io/docker-compose.yml"
  composerYMLPath="kuzzle-docker-compose.yml"
  if [ -z $DL_BIN ]; then
    failDL
  else
    writeBold "Downloading Kuzzle launch file..."
    echo
    $DL_BIN $DL_OPTS $composerYMLURL > $composerYMLPath
  fi
  echo
  writeBold "$GREEN" "[✔] The Kuzzle launch file has been successfully downloaded."
  writeBold          "    This script can launch Kuzzle automatically or you can do it"
  writeBold          "    manually using Docker Compose."
  write              "    To manually launch Kuzzle you can type the following command:"
  write              "    docker-compose -f $composerYMLPath up"
  while [[ "$launchTheStack" != [yYnN] ]]
    do
      promptBold "[❓] Do you want to automatically start Kuzzle now? (y/N) "
      read launchTheStack trash
      case "$launchTheStack" in
        [yY])
          echo
          writeBold "Starting Kuzzle..."
          $(command -v docker-compose) -f $composerYMLPath up -d
          echo
          writeBold "$GREEN" "[✔] Kuzzle is up and running!"
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
  echo
  writeBold "Where do we go from here?"
  shortHelp
}

shortHelp() {
  echo
  writeBold "* You can open this short help by calling ./setup.sh --help"
  writeBold "* You can start Kuzzle by typing:"
  write "  docker-compose -f $composerYMLPath up -d"
  writeBold "* You can see the logs of the Kuzzle stack by typing:"
  write "  docker-compose -f $composerYMLPath logs -f"
  writeBold "* You can check if everything is working by typing:"
  write "  curl -XGET http://localhost:7512/"
  writeBold "* You can stop Kuzzle by typing:"
  write "  docker-compose -f $composerYMLPath stop"
  writeBold "* You can restart Kuzzle by typing:"
  write "  docker-compose -f $composerYMLPath restart"
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
write     "* Feel free to join us on Gitter at https://gitter.im/kuzzleio/kuzzle"
write     "  if you need help."
echo
promptBold "$BLUE" "Press Enter to start."
read start

echo
writeBold "[ℹ] Checking system pre-requisites..."
echo

CHECK_ARCH=$(uname -a | grep x86_64)
if [ -z "${CHECK_ARCH}" ]; then
  echo
  writeBold "$RED" "[✖] Kuzzle runs on x86_64 architectures, which does not seem"
  writeBold "$RED" "    to be the architecture of your system."
  write            "    Sorry, you cannot launch Kuzzle on this machine."
  echo
  exit 4
fi

write "$GREEN" "[✔] Architecture is x86_64."

CHECK_MEM=$(awk '/MemTotal/{print $2}' /proc/meminfo)
MEM_REQ=4194304
if [ ${CHECK_MEM} -lt $MEM_REQ ]; then
  echo
  writeBold "$RED" "[✖] Kuzzle needs at least 4Gb of memory, which does not seem"
  writeBold "$RED" "    to be the available amount on your system."
  write            "    Sorry, you cannot launch Kuzzle on this machine."
  echo
  exit 5
fi

write "$GREEN" "[✔] Available memory is at least 4Gb."

CHECK_CORES=$(awk '/^processor/{print $3}' /proc/cpuinfo | tail -1)
if [ ${CHECK_CORES} -lt 3 ]; then
 echo
  writeBold "$RED" "[✖] Kuzzle needs at least 4 processor cores, which does not seem"
  writeBold "$RED" "    to be the available amount on your system."
  write            "    Sorry, you cannot launch Kuzzle on this machine."
  echo
  exit 6
fi

write "$GREEN" "[✔] At least 4 processor cores available."

if [ "$EUID" -ne 0 ]; then
  echo
  writeBold "$YELLOW" "[✖] This script needs to be executed with root privileges."
  echo
  exit 1
fi

write "$GREEN" "[✔] Script has root privileges."

if ! commandExists curl && ! commandExists wget; then
  INSTALL_DL=1
  write "$YELLOW" "[✖] cUrl is not installed."
  exit 1
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
  MIN_DOCKER_COMPOSE_VER=1.8.0
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

echo
writeBold "$GREEN" "[✔] All the requirements are met!"
writeBold          "    We are ready to install and start Kuzzle."

if [ -n "$DL_BIN" ]; then
  collectPersonalData
fi

startKuzzle
