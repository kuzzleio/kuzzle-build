#!/bin/bash

kuzzle_host=http://localhost:7512/_healthCheck
timeout=${HEALTHCHECK_TIMEOUT:-60}

docker-compose -f docker-compose/kuzzle-docker-compose.yml up -d

echo "[$(date --rfc-3339 seconds)] - Waiting for Kuzzle to be available"
for i in `seq 1 $timeout`;
do
    output=$( curl -s "$kuzzle_host" | grep \"status\":200 )
    if [[ ! -z "$output" ]]; then
      echo "[$(date --rfc-3339 seconds)] - Kuzzle is online"
      exit 0
    fi
    echo "[$(date --rfc-3339 seconds)] - Still trying to connect to $kuzzle_host"
    sleep 1
done

echo "[$(date --rfc-3339 seconds)] - Kuzzle does not seem to be online. Giving up"
exit 1
