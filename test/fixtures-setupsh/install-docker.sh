#!/bin/bash

install_via_apt() {
    apt-get update
    apt-get install -y \
        software-properties-common python-software-properties \
        lsb-core lsb-release \
        apt-transport-https \
        ca-certificates \
        curl \
        software-properties-common

    curl -fsSL https://download.docker.com/linux/$(lsb_release -si | tr 'A-Z' 'a-z')/gpg | apt-key add -

    apt-key fingerprint 0EBFCD88

    add-apt-repository \
    "deb [arch=amd64] https://download.docker.com/linux/$(lsb_release -si | tr 'A-Z' 'a-z') \
    $(lsb_release -cs) \
    stable"

    apt-get update

    apt-get install -y docker-ce
}

install_via_dnf() {
    dnf -y install dnf-plugins-core

    dnf config-manager \
        --add-repo \
        https://download.docker.com/linux/fedora/docker-ce.repo
    
    dnf install -y docker-ce
}

if [ $(command -v apt-get) ]; then
    install_via_apt
    exit 0
fi

if [ $(command -v dnf) ]; then
    install_via_dnf
    exit 0
fi