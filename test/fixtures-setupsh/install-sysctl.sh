#!/bin/bash

if [ $(command -v sysctl) ]; then
    exit 0
fi

# Detect dnf
if [ $(command -v dnf) ]; then
    dnf install -y procps
fi
