#!/bin/bash

if [ $SHOW_DEBUG -eq 1 ]; then
  ARGS="--show-debug"
fi

${BASH_SOURCE%/*}/test-setup.sh ubuntu-artful $ARGS

exit $?
