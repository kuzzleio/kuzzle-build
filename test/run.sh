#!/bin/bash

if [ $SHOW_DEBUG ]; then
  ARGS="--show-debug"
fi

${BASH_SOURCE%/*}/test-setup.sh ubuntu-artful $ARGS

exit $?