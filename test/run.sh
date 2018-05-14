#!/bin/bash

if [ "$SHOW_DEBUG" != "" ]; then
  ARGS="--show-debug"
fi

if [ -n $SETUPSH_TEST_DISTROS ]; then
  SETUPSH_TEST_DISTROS=(ubuntu-artful debian-jessie)
fi

for DISTRO in ${SETUPSH_TEST_DISTROS[*]}
do
  ${BASH_SOURCE%/*}/test-setup.sh $DISTRO $ARGS
  EXIT_VALUE=$?
  if [ $EXIT_VALUE -ne 0 ]; then
      exit $EXIT_VALUE
  fi
done

exit $EXIT_VALUE
