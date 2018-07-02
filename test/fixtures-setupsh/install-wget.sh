#!/bin/bash

if [ $(command -v wget) ]; then
    exit 0
fi

# Detect apt
if [ $(command -v apt-get) ]; then
    apt-get update
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