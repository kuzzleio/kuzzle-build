#!/bin/bash
set -e

# list of colors
BOLD=$(tput bold)
RED="\\033[1;31m"
BLUE="\\033[1;34m"
GREEN="\\033[1;32m"
YELLOW="\\033[1;33m"
NORMAL="\\033[0;39m"
RT="\r\n"

CURRENT_OS=Unknown
OS_IS_SUPPORTED=0

# Output a text with the selected color (reinit to normal at the end)
write() {
  echo -e " $1$2" "$NORMAL" >&2
}

writeBold() {
  echo -e "${BOLD} $1$2" "$NORMAL" >&2
}

promptBold() {
  echo -n -e "${BOLD} $1$2" "$NORMAL" >&2
}

commandExists() {
  command -v "$@" > /dev/null 2>&1
}

checkRoot() {
  if [ "$EUID" -ne 0 ]; then
    echo
    writeBold "$YELLOW" "[✖] This script needs to be executed with root privileges."
    echo
    exit 1
  fi
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
  echo
  # echo "Detected OS is" $CURRENT_OS
  case "$CURRENT_OS" in
    "UBUNTU" | "DEBIAN")
    {
      write "$GREEN" "[✔] Your OS ($CURRENT_OS) is officially supported."
      OS_IS_SUPPORTED=1
    } ;;
    *)
    {
      write "$YELLOW" "[✖] Your OS ($CURRENT_OS) is not officially supported."
      write           "    This means we didn't thoroughly test Kuzzle on your"
      write           "    system. It is likely to work, so you may want to continue."
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
            echo
            writeBold "$BLUE" "Ok. We encourage you to get in touch with the team (tech@kuzzle.io)"
            writeBold "$BLUE" "to request support for your system."
            echo
            if commandExists curl; then
              # TODO send feedback to analytics system to notify that an install
              # has been attempted on a non-supported system
              echo LOL
            fi
            exit 2
            ;;
          *)
            echo
            writeBold "$RED" "[✖] I did not understand your answer."
            ;;
        esac
      done
    } ;;
  esac
}

installDocker() {
  echo
  writeBold "[ℹ] Docker must be installed to run Kuzzle."
  writeBold "    This script can install Docker for you, otherwise you can do it manually."
  write     "    More information at https://docs.docker.com/engine/installation/"
  while [[ "$installDocker" != [yYnN] ]]
  do
    promptBold "[❓] Do you want to install Docker now? (y/N)"
    read installDocker trash
    case $installDocker in
      [yY])
        echo
        if commandExists curl; then
          writeBold "[ℹ] Installing Docker..."
          curl -sSL https://get.docker.com/ | sh
          echo
          writeBold "$GREEN" "[✔] Docker successfully installed."
        else
          writeBold "$RED" "[✖] curl needs to be installed to launch the Docker installation script,"
          writeBold "$RED" "    but it does not seem to be installed on your system."
          echo
          writeBold "$BLUE" "Please install curl and re-run this script."
          echo
          exit 3
        fi
        ;;
      [nN] | '')
        echo
        writeBold "$BLUE" "Ok. Please install Docker and re-run this script. "
        echo
        exit 0
        ;;
      *)
        echo
        writeBold "$RED" "[✖] I did not understand your answer."
        ;;
    esac
  done
}

installDockerCompose() {
  echo
  writeBold "[ℹ] Docker Compose must be installed to run Kuzzle."
  writeBold "    This script can install Docker Compose for you, otherwise you can do it manually."
  write     "    More information at https://docs.docker.com/compose/install/"
  while [[ "$installDockerCompose" != [yYnN] ]]
  do
    promptBold "[❓] Do you want to install Docker Compose now? (y/N)"
    read installDockerCompose trash
    case "$installDockerCompose" in
      [yY])
        if commandExists curl; then
          echo
          writeBold "Installing Docker Compose..."
          curl -L "https://github.com/docker/compose/releases/download/1.10.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
          chmod +x /usr/local/bin/docker-compose
          echo
          writeBold "$GREEN" "[✔] Docker Compose successfully installed."
        else
          writeBold "$RED" "[✖] curl needs to be installed to launch the Docker Compose installation script,"
          writeBold "$RED" "    but it does not seem to be installed on your system."
          echo
          writeBold "$BLUE" "Please install curl and re-run this script."
          echo
          exit 3
        fi
        ;;
      [nN] | '')
        echo
        writeBold "$BLUE" "Ok. Please install Docker Compose and re-run this script."
        echo
        exit 0
        ;;
      *)
        echo
        writeBold "$RED" "[✖] I did not understand your answer."
        ;;
    esac
  done
}

setupMapCount() {
  REQUIRED_MAP_COUNT=262144
  SYSCTL_CONF_FILE=/etc/sysctl.conf
  MAP_COUNT=$(sysctl -a 2> /dev/null | grep vm.max_map_count | cut -d'=' -f2 | tr -d ' ')

  if [ -z "$MAP_COUNT" ] || [ $MAP_COUNT -lt $REQUIRED_MAP_COUNT ]; then
    echo
    writeBold "[ℹ] The kernel configuration variable vm.max_map_count must be set to at least $REQUIRED_MAP_COUNT"
    writeBold "    for Kuzzle to work properly, but it seems to be set to $MAP_COUNT on your system."
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
            echo "vm.max_map_count=$REQUIRED_MAP_COUNT" > $SYSCTL_CONF_FILE
          else
            sed 's/vm.max_map_count=.+/vm.max_map_count=$REQUIRED_MAP_COUNT/g' $SYSCTL_CONF_FILE > $SYSCTL_CONF_FILE
          fi
          echo
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
        writeBold "$RED" "[✖] I did not understand your answer."
        ;;
      esac
    done
  fi
}

collectPersonalData() {
  echo
  writeBold  "[ℹ] Please let us know a little bit about youself."
  promptBold "    What's your email address?${NORMAL} (press Enter to skip)"
  read email trash
  promptBold "    What's your name?${NORMAL} (press Enter to skip)"
  read firstName lastName otherName yetAnotherName trash
  promptBold "    What do you plan to use Kuzzle for?${NORMAL} (press Enter to skip)"
  read purpose
  # TODO send collected data to analytics service
}

startKuzzle() {
  echo
  writeBold "Downloading Kuzzle launch file..."
  echo
  composerYMLURL="https://raw.githubusercontent.com/kuzzleio/kuzzle-build/master/docker-compose/kuzzle-docker-compose.yml"
  composerYMLPath="kuzzle-docker-compose.yml"
  curl -XGET $composerYMLURL > $composerYMLPath
  echo
  writeBold "$GREEN" "[✔] The Kuzzle launch file has been successfully downloaded."
  writeBold          "    This script can launch Kuzzle automatically or you can do it"
  writeBold          "    manyally using Docker Compose."
  write              "    To manyally launch Kuzzle you can type the following command:"
  write              "    docker-compose -f $composerYMLPath up"
  while [[ "$launchTheStack" != [yYnN] ]]
    do
      promptBold "[❓] Do you want to start Kuzzle now? (y/N) "
      read launchTheStack trash
      case "$launchTheStack" in
        [yY])
          echo
          writeBold "Starting Kuzzle..."
          docker-compose -f $composerYMLPath up -d
          echo
          write "$GREEN" "[✔] Kuzzle is up and running!"
          ;;
        [nN] | '')
          echo
          writeBold "$BLUE" "Ok."
          launchTheStack=n
          ;;
        *)
          echo
          writeBold "$RED" "[✖] I did not understand your answer."
          ;;
      esac
    done
  echo
  writeBold "Where do we go from here?"
  writeBold "* You can start Kuzzle by typing:"
  write "  docker-compose -f $composerYMLPath up -d"
  writeBold "* You can see the logs of the Kuzzle stack by typing:"
  write "  docker-compose -f $composerYMLPath logs -f"
  writeBold "* You can check if everything is working by typing:"
  write "  curl -XGET http://localhost:7511/"
  writeBold "* You can stop Kuzzle by typing:"
  write "  docker-compose -f $composerYMLPath stop"
  writeBold "* You can restart Kuzzle by typing:"
  write "  docker-compose -f $composerYMLPath restart"
  writeBold "* You can read the docs at http://docs.kuzzle.io/"
  echo
}

# Main execution routine
# ===========================

echo
writeBold "# Kuzzle Setup"
writeBold "  ============"
echo
writeBold "This script will help you launch Kuzzle and install"
writeBold "all the necessary dependencies."
echo
write     "* You can refer to http://docs.kuzzle.io/ if you need better"
write     "  understanding of the installation process."
write     "* Feel free to join us on Gitter at https://gitter.im/kuzzleio/kuzzle"
write     "  to get help in real time."

checkRoot
# TODO check architecture (32 vs 64)
# TODO check available memory
findOSType
isOSSupported

if ! commandExists docker; then
  installDocker
fi

if ! $(docker run hello-world > /dev/null); then
  echo
  writeBold "$RED" "[✖] Docker does not seem to be running on your system."
  writeBold "$RED" "    Please start the Docker daemon and re-run this script"
  write            "    More information at https://docs.docker.com/engine/admin/"
  echo
  exit 4
fi

if ! commandExists docker-compose; then
  installDockerCompose
fi

setupMapCount
collectPersonalData
startKuzzle
