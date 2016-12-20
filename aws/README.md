# AWS

## Prerequisite

You need:
* [Packer](https://www.packer.io)

## Build AMI of the proxy for ubuntu 16.04 x64

```sh
$ packer build -var 'access_key=<your access key>' -var 'secret_key=<your secret key>' kuzzle-proxy-ami-hvm-ubuntu-16.04-x64.json
```

## Build AMI of the proxy for ubuntu 16.04 x64

```sh
$ packer build -var 'access_key=<your access key>' -var 'secret_key=<your secret key>' kuzzle-proxy-ami-hvm-ubuntu-16.04-x64.json
```

## Build AMI of kuzzle for ubuntu 16.04 x64

```sh
$ packer build -var 'access_key=<your access key>' kuzzle-ami-hvm-ubuntu-16.04-x64.json
```
