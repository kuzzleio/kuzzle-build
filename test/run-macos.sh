#!/bin/bash

LOCK_FILE=/tmp/test-setupsh.lock
LOCK_SLEEP=2
LOCK_MAX_RETRY=250
LOCK_RETRY=0

if [ -f $LOCK_FILE ]; then
    echo -n "Another test is ongoing, waiting for it to finish..."
fi
while [ -f  $LOCK_FILE ] && [ $LOCK_RETRY -lt $LOCK_MAX_RETRY ]; do
    sleep $LOCK_SLEEP
    echo -n "."
    LOCK_RETRY=$(expr $LOCK_RETRY + 1)
done

trap clean_lock EXIT INT
touch $LOCK_FILE

echo
echo " Testing Setup.sh on OSX"
echo " ================================"

WORK_BRANCH=$1

if [ "$WORK_BRANCH" = "" ]; then
  WORK_BRANCH=1.x
fi

cd kuzzle-build
git fetch
git checkout $WORK_BRANCH
git pull

test/test-setup.macos.sh
EXIT_VALUE=$?

[[ -d kuzzle ]] && rm -rf kuzzle

clean_lock() {
    [[ -f $LOCK_FILE ]] && rm $LOCK_FILE
}

exit $EXIT_VALUE
