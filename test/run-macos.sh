#!/bin/bash

sshd &
echo "public ip: "
echo $(curl -s "http://ifconfig.me")

while true; do
	echo "Waiting a little bit..."
	sleep 3
done