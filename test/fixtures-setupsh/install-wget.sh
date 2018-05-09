#!/bin/bash

# Detect apt
if [ $(command -v apt-get) ]; then
    apt-get install -y wget
    exit 0
fi

if [ $(command -v dnf) ]; then
    dnf install -y wget
    exit 0
fi

# Detect yum
if [ $(command -v yum) ]; then
    yum install -y wget
    exit 0
fi