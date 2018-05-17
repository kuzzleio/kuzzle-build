# Docker-compose files to run the Kuzzle stack

Supported OS: [Debian Jessie](https://kuzzleio.github.io/kuzzle-build/setupsh-badges/debian-jessie.svg) [Fedora](https://kuzzleio.github.io/kuzzle-build/setupsh-badges/fedora.svg) [Ubuntu Artful](https://kuzzleio.github.io/kuzzle-build/setupsh-badges/ubuntu-artful.svg) 

The docker-compose files in the `docker-compose` dir will allow you to run Kuzzle with optional SSL support.

## The `setup.sh` installation helper

Use the `setup.sh` script to perform a requirements check on your system and automatically start Kuzzle.
The script will _not_ install any dependencies on your behalf, but will instead give you hints on how to do it.

To run it, you don't need to clone this repository, you can just type

```
$ bash -c "$(curl https://raw.githubusercontent.com/kuzzleio/kuzzle-build/master/setup.sh)"
```

Or, you can clone this repository and run the script with options

```
$ ./setup.sh --no-run
```

only performs the system requirements checks and pulls the Docker images for the stack, without running it.

After running the stack, the `setup.sh` script checks whether Kuzzle is up or not within a delay of 60 seconds. If your system is slow, you can give additional delay by specifying the `CONNECT_TO_KUZZLE_WAIT_TIME_BETWEEN_RETRY` environment variable

```
$ CONNECT_TO_KUZZLE_WAIT_TIME_BETWEEN_RETRY=4 ./setup.sh
```

This will cause `setup.sh` to perform 30 checks every 4 seconds, for a total delay of 120 seconds.