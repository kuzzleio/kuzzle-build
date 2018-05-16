#!/bin/bash

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
  if [ $EXIT_VALUE -ne 0 ]; then
      exit $EXIT_VALUE
  fi
done

exit $EXIT_VALUE
