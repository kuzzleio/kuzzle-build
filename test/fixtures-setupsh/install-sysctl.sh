#!/bin/bash

if [ $(command -v sysctl) ]; then
    exit 0
fi

# Detect apt
if [ $(command -v apt-get) ]; then
    exit 1
fi

# Detect dnf
if [ $(command -v dnf) ]; then
    dnf install -y procps
    exit 0
fi

# Detect yum
if [ $(command -v yum) ]; then
    exit 1
fi
