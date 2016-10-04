# This is a repository to build an AMI for AWS or DigitalOcean

## Prerequisite

You need https://www.packer.io

## AWS

### Build AMI of the proxy for ubuntu 16.04 x64

```sh
$ packer build -var 'access_key=<your access key>' -var 'secret_key=<your secret key>' kuzzle-proxy-ami-hvm-ubuntu-16.04-x64.json
```

## AWS

### Build AMI of the proxy for ubuntu 16.04 x64

```sh
$ packer build -var 'access_key=<your access key>' -var 'secret_key=<your secret key>' kuzzle-proxy-ami-hvm-ubuntu-16.04-x64.json
```

### Build AMI of kuzzle for ubuntu 16.04 x64

```sh
$ packer build -var 'access_key=<your access key>' kuzzle-ami-hvm-ubuntu-16.04-x64.json
```

## DigitalOcean

### Build image of the proxy and kuzzle for DigitalOcean

```sh
$ packer build -var 'api_token=<your api token>' kuzzle-fullstack-digitalocean-ubuntu-16.04-x64.json
```