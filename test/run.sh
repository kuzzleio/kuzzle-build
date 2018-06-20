#!/bin/bash

set -x 

FINAL_EXIT_VALUE=0
BADGES_DIR=./setupsh-badges
DEFAULT_DISTROS=(fedora ubuntu-artful debian-jessie osx)
sudo sysctl -w vm.max_map_count=262144

[[ -d $BADGES_DIR ]] || mkdir $BADGES_DIR

if [ "$SETUPSH_SHOW_DEBUG" != "" ]; then
  ARGS="--show-debug"
fi

if [ -z $SETUPSH_TEST_DISTROS ]; then
  DISTROS=$DEFAULT_DISTROS
else
  IFS=', ' read -r -a DISTROS <<< "$SETUPSH_TEST_DISTROS"
fi

for DISTRO in ${DISTROS[*]}
do
  if [ "$DISTRO" = "osx" ]; then
    ssh $MAC_USER@$MAC_HOST "./test-setup.sh $TRAVIS_BRANCH"
  else
    ${BASH_SOURCE%/*}/test-setup.sh $DISTRO $ARGS
  fi
  EXIT_VALUE=$?
  FORMATTED_DISTRO=$(echo $DISTRO | tr '-' '%20')
  if [ $EXIT_VALUE -ne 0 ]; then
      FINAL_EXIT_VALUE=$EXIT_VALUE
      curl -L https://img.shields.io/badge/setup.sh-$FORMATTED_DISTRO-red.svg -o $BADGES_DIR/$DISTRO.svg
  else
      curl -L https://img.shields.io/badge/setup.sh-$FORMATTED_DISTRO-green.svg -o $BADGES_DIR/$DISTRO.svg      
  fi
done

exit $FINAL_EXIT_VALUE
