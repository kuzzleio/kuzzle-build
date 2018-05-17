#!/bin/bash

FINAL_EXIT_VALUE=0
BADGES_DIR=./setupsh-badges

sysctl -w vm.max_map_count=262144

[[ -d $BADGES_DIR ]] || mkdir $BADGES_DIR

if [ "$SETUPSH_SHOW_DEBUG" != "" ]; then
  ARGS="--show-debug"
fi

if [ -z $SETUPSH_TEST_DISTROS ]; then
  DISTROS=(fedora ubuntu-artful debian-jessie)
else
  IFS=', ' read -r -a DISTROS <<< "$SETUPSH_TEST_DISTROS"
fi

for DISTRO in ${DISTROS[*]}
do
  ${BASH_SOURCE%/*}/test-setup.sh $DISTRO $ARGS
  EXIT_VALUE=$?
  FORMATTED_DISTRO=$(echo $DISTRO | tr '-' '%20')
  if [ $EXIT_VALUE -ne 0 ]; then
      $FINAL_EXIT_VALUE=$EXIT_VALUE
      curl -L https://img.shields.io/badge/setup.sh-$FORMATTED_DISTRO-red.svg -o $BADGES_DIR/$DISTRO.svg
  else
      curl -L https://img.shields.io/badge/setup.sh-$FORMATTED_DISTRO-green.svg -o $BADGES_DIR/$DISTRO.svg      
  fi
done

exit $FINAL_EXIT_VALUE
