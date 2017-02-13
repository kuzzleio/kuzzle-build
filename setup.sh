#!/bin/bash
set -e

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
            writeBold "$BLUE" "Ok. Would you like to notify the Kuzzle team that you tried"
            writeBold "$BLUE" "to install Kuzzle on an unsupported OS? This will increase"
            writeBold "$BLUE" "the chances that your OS will be supported one day."
            write "The following data will be sent to the Kuzzle team:"
            write " * OS = $CURRENT_OS"
            echo
            promptBold "[❓] Do you want to notify the Kuzzle team? (y/N)"
            read notifyTeam trash
            case "$notifyTeam" in
              [yY])
                # TODO send feedback to analytics system to notify that an install
                # has been attempted on a non-supported system
                ;;
              *)
                echo
                writeBold "$BLUE" "Ok. We encourage you to get in touch with the team (tech@kuzzle.io)"
                writeBold "$BLUE" "to request support for your system."
                echo
                ;;
            esac
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

installCurl() {
  echo
  writeBold "[ℹ] cUrl must be installed to run Kuzzle."
  writeBold "    This script can install cUrl for you, otherwise you can do it manually."
  write     "    We encourage you to use your package manager."
  while [[ "$installCurl" != [yYnN] ]]
  do
    promptBold "[❓] Do you want to install cUrl now? (y/N)"
    read installCurl trash
    case $installCurl in
      [yY])
        echo
        if commandExists apt-get; then
          apt-get -y install curl
        elif commandExists yum; then
          yum install curl
        else
          echo
          writeBold "$YELLOW" "[✖] Sorry, I didn't find a suitable package manager to install cUrl."
          writeBold           "    I only support apt-get and yum. You know better than me how to do this."
          echo
          exit 8
        fi
        ;;
      [nN] | '')
        echo
        writeBold "$BLUE" "Ok. Please install cUrl and re-run this script. "
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
        elif commandExists wget; then
          writeBold "[ℹ] Installing Docker..."
          wget -qO- https://get.docker.com/ | sh
          echo
          writeBold "$GREEN" "[✔] Docker successfully installed."
        else
          writeBold "$RED" "[✖] curl or wget need to be installed to launch the Docker installation script,"
          writeBold "$RED" "    but none seems to be installed on your system."
          echo
          writeBold "$BLUE" "Please install curl or wget and re-run this script."
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
          curl -L "https://github.com/docker/compose/releases/download/1.10.0/docker-compose-$(uname -s)-$(uname -m)" -o $DOCKER_COMPOSE_BIN
          chmod +x $DOCKER_COMPOSE_BIN
          echo
          writeBold "$GREEN" "[✔] Docker Compose successfully installed."
        elif commandExists wget; then
          echo
          writeBold "Installing Docker Compose..."
          wget -O $DOCKER_COMPOSE_BIN "https://github.com/docker/compose/releases/download/1.10.0/docker-compose-$(uname -s)-$(uname -m)"
          chmod +x $DOCKER_COMPOSE_BIN
          echo
          writeBold "$GREEN" "[✔] Docker Compose successfully installed."
        else
          writeBold "$RED" "[✖] curl or wget need to be installed to launch the Docker Compose installation script,"
          writeBold "$RED" "    but none seems to be installed on your system."
          echo
          writeBold "$BLUE" "Please install curl or wget and re-run this script."
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
  SYSCTL_CONF_FILE=/etc/sysctl.conf
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
          echo "vm.max_map_count=$REQUIRED_MAP_COUNT" >> $SYSCTL_CONF_FILE
        else
          sed 's/vm.max_map_count=.+/vm.max_map_count=$REQUIRED_MAP_COUNT/g' > ${TMPDIR-/tmp}/sysctl.tmp
          mv ${TMPDIR-/tmp}/sysctl.tmp $SYSCTL_CONF_FILE
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
}

collectPersonalData() {
  echo
  writeBold  "[ℹ] Please let us know a little bit about youself."
  promptBold "    What's your email address?${NORMAL} (press Enter to skip)"
  read email trash
  promptBold "    What's your full name?${NORMAL} (press Enter to skip)"
  read firstName lastName otherName yetAnotherName trash
  promptBold "    What do you plan to use Kuzzle for?${NORMAL} (press Enter to skip)"
  read purpose
  # TODO send collected data to analytics service
}

startKuzzle() {
  composerYMLURL="http://kuzzle.io/docker-compose.yml"
  composerYMLPath="kuzzle-docker-compose.yml"
  if commandExists curl; then
    echo
    writeBold "Downloading Kuzzle launch file..."
    echo
    curl -XGET $composerYMLURL > $composerYMLPath
  elif commandExists wget; then
    echo
    writeBold "Downloading Kuzzle launch file..."
    echo
    wget -O $composerYMLPath $composerYMLURL
  else
    writeBold "$RED" "[✖] curl or wget need to be installed to download the Kuzzle launch file,"
    writeBold "$RED" "    but none seems to be installed on your system."
    echo
    writeBold "$BLUE" "Please install curl or wget and re-run this script."
    echo
    exit 3
  fi
  echo
  writeBold "$GREEN" "[✔] The Kuzzle launch file has been successfully downloaded."
  writeBold          "    This script can launch Kuzzle automatically or you can do it"
  writeBold          "    manually using Docker Compose."
  write              "    To manually launch Kuzzle you can type the following command:"
  write              "    docker-compose -f $composerYMLPath up"
  while [[ "$launchTheStack" != [yYnN] ]]
    do
      promptBold "[❓] Do you want to start Kuzzle now? (y/N) "
      read launchTheStack trash
      case "$launchTheStack" in
        [yY])
          echo
          writeBold "Starting Kuzzle..."
          $(command -v docker-compose) -f $composerYMLPath up -d
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
write     "  if you need help."

CHECK_ARCH=$(uname -a | grep x86_64)
if [ -z "${CHECK_ARCH}" ]; then
  echo
  writeBold "$RED" "[✖] Kuzzle runs on x86_64 architectures, which does not seem"
  writeBold "$RED" "    to be the architecture of your system."
  write            "    Sorry, you cannot launch Kuzzle on this machine."
  echo
  exit 4
fi

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

CHECK_CORES=$(awk '/^processor/{print $3}' /proc/cpuinfo | tail -1)
if [ ${CHECK_CORES} -lt 3 ]; then
 echo
  writeBold "$RED" "[✖] Kuzzle needs at least 4 processor cores, which does not seem"
  writeBold "$RED" "    to be the available amount on your system."
  write            "    Sorry, you cannot launch Kuzzle on this machine."
  echo
  exit 6
fi

checkRoot

findOSType
isOSSupported

if ! commandExists curl; then
  installCurl
fi

if ! commandExists docker; then
  installDocker
fi

CHECK_DOCKER_RUN=$(docker run hello-world &> /dev/null)
if ! ${CHECK_DOCKER_RUN} ; then
  echo
  writeBold "$RED" "[✖] Docker does not seem to be running on your system."
  writeBold "$RED" "    Please start the Docker daemon and re-run this script"
  write            "    More information at https://docs.docker.com/engine/admin/"
  echo
  exit 5
fi

if ! commandExists docker-compose; then
  installDockerCompose
fi

CHECK_MAP_COUNT=$(sysctl -a 2> /dev/null | grep vm.max_map_count | cut -d'=' -f2 | tr -d ' ')
REQUIRED_MAP_COUNT=262144
if [ -z "${CHECK_MAP_COUNT}" ] || [ ${CHECK_MAP_COUNT} -lt $REQUIRED_MAP_COUNT ]; then
  setupMapCount
fi

collectPersonalData
startKuzzle
