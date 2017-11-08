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
COMPOSER_YML_URL="https://raw.githubusercontent.com/kuzzleio/kuzzle-build/master/docker-compose/kuzzle-docker-compose.yml"
SUPPORT_MAIL="support@kuzzle.io"
KUZZLE_DIR="${HOME}/.kuzzle"
COMPOSER_YML_PATH="${KUZZLE_DIR}/docker-compose.yml"
README_PATH="${KUZZLE_DIR}/README"
FIRST_INSTALL=0
SUDO_PREFIX=""

docker_out=$(docker info 2>&1)
if [[ "$?" -gt "0" ]]; then
  # echo NOT_HAZ_GROUP_DOCKER
  unset HAS_GROUP_DOCKER
else
  # echo HAZ_GROUP_DOCKER
  HAS_GROUP_DOCKER=1
fi

DL_BIN=$(command -v curl)
DL_OPTS="-sSL"
UL_OPTS='-H Content-Type:application/json --data'

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

writeLnFile() {
  echo "$1" >> $README_PATH
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
        writeBold "[❓] Do you want to continue? (y/N)"
        echo -n "> "
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
              echo -n "> "
              read notifyTeam trash
              case "$notifyTeam" in
                [yY])
                  writeBold "[❓] Ok. What is your email address?"
                  echo -n "> "
                  read email trash
                  $DL_BIN $UL_OPTS '{"type": "notify-when-os-supported", "uid": "'$UUID'", "os": "'$CURRENT_OS'", "email": "'$email'"}' $ANALYTICS_URL &> /dev/null
                  ;;
                *)
                  echo
                  writeBold "$BLUE" "Ok. We encourage you to get in touch with the team ($SUPPORT_MAIL)"
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

failDL() {
  echo
  writeBold "$YELLOW" "[✖] curl is necessary to install Kuzzle. However,"
  writeBold "$YELLOW" "     it does not seem to be available on your system."
  write               "     Please install curl and re-run this script."
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
    if [ $EUID != 0 ]; then
      SUDO_PREFIX="sudo"
    fi
    installDockerCmd="$DL_BIN $DL_OPTS https://get.docker.com/ | $SUDO_PREFIX sh"
    write "    If you agree, I will run the following command"
    write "    $installDockerCmd"
    echo
    echo -n "> "
    read installDocker trash
    case $installDocker in
      [yY])
        if [ -z $DL_BIN ]; then
          failDL
        else
          writeBold "[ℹ] Installing Docker..."
          echo
          eval $installDockerCmd
          if [ $? -eq 0 ]; then
            writeBold "$GREEN" "[✔] Docker successfully installed."
          else
            echo
            writeBold "$RED" "[✖] Ooops! Docker installation failed."
            write            "    Something has gone wrong installing docker."
            write            "    Please, refer to https://docs.docker.com/engine/installation/"
            echo
            exit $?
          fi
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
    if [ $EUID != 0 ]; then
      SUDO_PREFIX="sudo"
    fi
    installDockerComposeCmd_1="$DL_BIN $DL_OPTS "https://github.com/docker/compose/releases/download/1.12.0/docker-compose-$(uname -s)-$(uname -m)" > /tmp/docker-compose"
    installDockerComposeCmd_2="$SUDO_PREFIX mv /tmp/docker-compose $DOCKER_COMPOSE_BIN"
    installDockerComposeCmd_3="$SUDO_PREFIX chmod +x $DOCKER_COMPOSE_BIN"
    write "    If you agree, I will run the following commands"
    write "    $installDockerComposeCmd_1"
    write "    $installDockerComposeCmd_2"
    write "    $installDockerComposeCmd_3"
    echo -n "> "
    read installDockerCompose trash
    case "$installDockerCompose" in
      [yY])
        if [ -z $DL_BIN ]; then
          failDL
        else
          writeBold "[ℹ] Installing Docker Compose..."
          echo
          eval $installDockerComposeCmd_1
          eval $installDockerComposeCmd_2
          eval $installDockerComposeCmd_3
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
    if [ $EUID != 0 ]; then
      SUDO_PREFIX="sudo"
    fi
    setMapCmd_1="$SUDO_PREFIX sysctl -w vm.max_map_count=$REQUIRED_MAP_COUNT"
    if [ -z "$MAP_COUNT" ]; then
      setMapCmd_2="echo "vm.max_map_count=$REQUIRED_MAP_COUNT" | $SUDO_PREFIX tee -a $SYSCTL_CONF_FILE"
      setMapCmd_3=""
    else
      setMapCmd_2="sed 's/vm.max_map_count=.+/vm.max_map_count=$REQUIRED_MAP_COUNT/g' > ${TMPDIR-/tmp}/sysctl.tmp"
      setMapCmd_3="$SUDO_PREFIX mv ${TMPDIR-/tmp}/sysctl.tmp $SYSCTL_CONF_FILE"
    fi
    write "    If you agree, I will run the following commands"
    write "    $setMapCmd_1"
    write "    $setMapCmd_2"
    write "    $setMapCmd_3"
    echo -n "> "
    read setVmParam trash
    case "$setVmParam" in
      [yY])
        writeBold "Setting kernel variable vm.max_map_count to $REQUIRED_MAP_COUNT..."
        echo
        eval $setMapCmd_1
        eval $setMapCmd_2
        eval $setMapCmd_3
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
  writeBold "[❓] What are you going to use Kuzzle for?"
  write     "    1) IoT"
  write     "    2) Web"
  write     "    3) Mobile"
  write     "    4) Machine-to-machine"
  write     "    5) Other"
  write     "    *) Stop bugging me"
  echo -n "> "
  read purpose trash
  if [ -n $purpose ] && [[ $purpose -ge 1 ]] && [[ $purpose -le 5 ]]; then
    case "$purpose" in
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
  else
    writeBold "$BLUE" "Ok."
    echo
    purpose="Stop bugging me"
  fi
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
    writeBold "[ℹ] Downloading Kuzzle launch file..."
    $DL_BIN $DL_OPTS $COMPOSER_YML_URL > $COMPOSER_YML_PATH
  fi

  if [ $? -ne 0 ]; then
    echo
    writeBold "$RED" "[✖] Ooops! Something went wrong downloading Kuzzle launch file."
    write            "    This is probably due to network problems."
    echo
    exit $?
  fi

  writeBold "$GREEN" "[✔] The Kuzzle launch file has been successfully downloaded."

  if [ -z $HAS_GROUP_DOCKER ]; then
    launchKuzzleCmd="sudo $(command -v docker-compose) -f $COMPOSER_YML_PATH up -d"
  else
    launchKuzzleCmd="$(command -v docker-compose) -f $COMPOSER_YML_PATH up -d"
  fi

  # pullKuzzle()

  while [[ "$launchTheStack" != [yYnN] ]]; do
    echo
    writeBold "[❓] Do you want to start Kuzzle now? (y/N)"
    write "    If you agree, I will execute the following command"
    write "    $launchKuzzleCmd"
    echo -n "> "
    read launchTheStack trash
    case "$launchTheStack" in
      [yY])
        echo
        writeBold "[ℹ] Starting Kuzzle..."
        write "    (be patient, this may take a while)"
        $DL_BIN $UL_OPTS '{"type": "starting-kuzzle", "uid": "'$UUID'"}' $ANALYTICS_URL &> /dev/null
        echo
        eval $launchKuzzleCmd
        if [ $? -eq 0 ]; then
          isKuzzleRunning
        else
          echo
          writeBold "$RED" "[✖] Ooops! Something went wrong starting Kuzzle."
          write            "    You can try to execute manually the following command"
          write            "    $launchKuzzleCmd"
          write            "    and take a look at the output."
          echo
          write            "    Feel free to join us on Gitter at $GITTER_URL to report this problem."
          echo
          exit $?
        fi
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

installSystemService() {
  KUZZLE_OPT_PATH="/opt/kuzzle"
  SYSTEMD_FILE_PATH="/lib/systemd/system/kuzzle.service"
  if [[ `systemctl` =~ -\.mount ]]; then
    echo
    writeBold "[❓] Would you like to install Kuzzle as a systemd service? (y/N)"
    if [ $EUID != 0 ]; then
      SUDO_PREFIX="sudo"
    fi
    if [ ! -d $KUZZLE_OPT_PATH ]; then
      systemServCmd_1="$SUDO_PREFIX mkdir $KUZZLE_OPT_PATH"
    fi
    systemServCmd_2="$SUDO_PREFIX cp $COMPOSER_YML_PATH $KUZZLE_OPT_PATH/docker-compose.yml"
    systemServCmd_3="$SUDO_PREFIX systemctl enable $SYSTEMD_FILE_PATH"
    write "   If you agree, I will execute the following commands"
    if [ ! -z "$systemServCmd_1" ]; then
      write "   $systemServCmd_1"
    fi
    write "   $systemServCmd_2"
    write "   Then, I will create a systemd file in $SYSTEMD_FILE_PATH and enable it"
    write "   $systemServCmd_3"
    echo -n "> "
    read systemdService trash
      case "$systemdService" in
        [yY])
          if [ ! -z "$systemServCmd_1" ]; then
            eval $systemServCmd_1
          fi
          eval $systemServCmd_2
          SERVICE_FILE_CONTENT=$(cat << EndOfMessage
[Unit]
Description=Kuzzle
After=docker.service
Requires=docker.service

[Service]
WorkingDirectory=$KUZZLE_OPT_PATH
ExecStartPre=-/usr/local/bin/docker-compose kill
ExecStartPre=-/usr/local/bin/docker-compose rm -f
ExecStartPre=-/usr/local/bin/docker-compose pull
ExecStart=/usr/local/bin/docker-compose up
ExecStop=/usr/local/bin/docker-compose kill

[Install]
WantedBy=multi-user.target
EndOfMessage
)
          $SUDO_PREFIX tee "$SYSTEMD_FILE_PATH" <<< "$SERVICE_FILE_CONTENT" &> /dev/null
          eval $systemServCmd_3
          if [ $? -eq 0 ]; then
            echo
            writeBold "$GREEN" "[✔] Kuzzle service successfully installed."
            write     "    Use the following commands to manage Kuzzle"
            write     "    systemctl start|stop|status kuzzle"
            echo
            write     "[ℹ] You'll probably need root privileges to use them"
          else
            echo
            writeBold "$RED" "[✖] Ooops! Kuzzle service installation failed."
          fi
        ;;
        *)
          writeBold "$BLUE" "Ok."
        ;;
      esac
  fi
}

pullKuzzle() {
  echo
  writeBold "[❓] Do you want to pull the latest version of Kuzzle now? (y/N)"
  if [ -z $HAS_GROUP_DOCKER ]; then
    write "    You might be prompted for your password since you are not"
    write "    included in the docker group."
  fi
  echo -n "> "
  read pullLatest trash
  case "$pullLatest" in
    [yY])
      echo
      write "[ℹ] Pulling latest version Kuzzle..."
      $DL_BIN $UL_OPTS '{"type": "pulling-latest-containers", "uid": "'$UUID'"}' $ANALYTICS_URL &> /dev/null
      if [ -z $HAS_GROUP_DOCKER ]; then
        sudo $(command -v docker-compose) -f $COMPOSER_YML_PATH pull
      else
        $(command -v docker-compose) -f $COMPOSER_YML_PATH pull
      fi
      if [ $? -eq 0 ]; then
        writeBold "$GREEN" "[✔] Done."
      else
        echo
        writeBold "$RED" "[✖] Ooops! Pulling Kuzzle has failed."
        write            "    Try doing it manually and check the errors"
        write            "    docker-compose -f $COMPOSER_YML_PATH up"
        echo
        exit $?
      fi

      $DL_BIN $UL_OPTS '{"type": "pulled-latest-containers", "uid": "'$UUID'"}' $ANALYTICS_URL &> /dev/null
      ;;
    *)
      writeBold "$BLUE" "Ok."
      ;;
  esac
}

isKuzzleRunning() {
  CONNECTION_TRIES=0
  echo -n " "
  while ! curl -f -s -o /dev/null "http://localhost:7512" && [ $CONNECTION_TRIES -lt 30 ]
  do
    CONNECTION_TRIES=$(($CONNECTION_TRIES + 1))
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
    writeBold "[ℹ] You can also inspect the logs by typing"
    write     "    docker-compose -f $COMPOSER_YML_PATH logs -f"
    echo
    writeBold "$YELLOW" "Sorry for the inconvenience."
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
  writeBold "* You can open this short help by typing"
  write "  ./setup.sh --help"
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

writeHelpToFile() {
  echo "" > $README_PATH
  writeLnFile "# Kuzzle Short Help"
  writeLnFile "  ================="
  writeLnFile ""
  writeLnFile "* You can start Kuzzle by typing:"
  writeLnFile "  docker-compose -f $COMPOSER_YML_PATH up -d"
  writeLnFile "* You can see the logs of the Kuzzle stack by typing:"
  writeLnFile "  docker-compose -f $COMPOSER_YML_PATH logs -f"
  writeLnFile "* You can check if everything is working by typing:"
  writeLnFile "  curl -XGET http://localhost:7512/"
  writeLnFile "* You can stop Kuzzle by typing:"
  writeLnFile "  docker-compose -f $COMPOSER_YML_PATH stop"
  writeLnFile "* You can restart Kuzzle by typing:"
  writeLnFile "  docker-compose -f $COMPOSER_YML_PATH restart"
  writeLnFile "* You can read the docs at http://docs.kuzzle.io/"
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
MEM_REQ=3000000
if (( "$CHECK_MEM" < "$MEM_REQ" )); then
  echo
  writeBold "$YELLOW" "[!] Kuzzle needs at least 3Gb of memory, which does not seem"
  writeBold "$YELLOW" "    to be the available amount on your system (${CHECK_MEM})."
  write               "    Performance might be poor."
  echo
else
  write "$GREEN" "[✔] Available memory is at least 3Gb."
fi

if ! commandExists curl; then
  write "$YELLOW" "[✖] cUrl is not installed."
  exit 1
elif commandExists curl; then
  write "$GREEN" "[✔] cUrl is installed."
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

$DL_BIN $UL_OPTS '{"type": "start-setup", "uid": "'$UUID'", "first-install": "'$FIRST_INSTALL'"}' $ANALYTICS_URL &> /dev/null

echo
writeBold "$GREEN" "[✔] All the requirements are met!"
promptBold "$BLUE" "    Press Enter to install and start Kuzzle."
read proceedInstall

startKuzzle
installSystemService
collectPersonalData

writeBold "# Where do we go from here?"
writeBold "  ========================="
shortHelp

echo
writeBold "[ℹ] This short help has been written to into"
write     "    $README_PATH"
writeHelpToFile
echo
