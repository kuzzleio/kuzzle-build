# DigitalOcean

## Prerequisite

You need:
* [Packer](https://www.packer.io)

## Build image of the proxy and kuzzle for DigitalOcean

```sh
$ packer build -var 'api_token=<your api token>' kuzzle-fullstack-digitalocean-ubuntu-16.04-x64.json
```