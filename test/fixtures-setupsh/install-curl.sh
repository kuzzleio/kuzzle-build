#!/bin/bash

# Detect apt
if [ $(command -v apt-get) ]; then
    apt-get install -y curl
    exit 0
fi

# Detect yum
if [ $(command -v yum) ]; then
    yum install -y curl
    exit 0
fi