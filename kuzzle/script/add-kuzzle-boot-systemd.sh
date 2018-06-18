#!/bin/bash
echo -e "[Unit]

Description=Kuzzle Service

After=docker.service

Requires=docker.service

[Service]

Type=simple

WorkingDirectory=/Users/yvanstern/Dev/Projects/Kuzzle/setup/kuzzle-build/kuzzle

ExecStart=/usr/local/bin/docker-compose -f /Users/yvanstern/Dev/Projects/Kuzzle/setup/kuzzle-build/./kuzzle/docker-compose.yml up

ExecStop=/usr/local/bin/docker-compose -f /Users/yvanstern/Dev/Projects/Kuzzle/setup/kuzzle-build/./kuzzle/docker-compose.yml stop

Restart=on-abort

[Install]

WantedBy=multi-user.target" > /etc/systemd/system/kuzzle.service
systemctl enable kuzzle
