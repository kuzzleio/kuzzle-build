#!/bin/bash

export CONNECT_TO_KUZZLE_MAX_RETRY=180
export SETUPSH_SHOW_DEBUG=1

cd ${BASH_SOURCE%/*}
./setupsh.should "Install Kuzzle successfully" "Kuzzle successfully installed" 0

EXIT_VALUE=$?

docker-compose -f kuzzle/docker-compose.yml kill

exit $EXIT_VALUE