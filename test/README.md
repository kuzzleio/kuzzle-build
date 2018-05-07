# Setup.sh test developer's handbook

Setup.sh tests are performed by [expect](https://linux.die.net/man/1/expect), a linux command
that allows to spawn a program, interact with by sending input to it and doing assertions on
its output.

The aim of the the testing suite is the following:

* cover the maximum code surface of the setup.sh script;
* test the script in many Linux-type environments (Ubuntu, Debian, RedHat, Fedora...);
* enable the developer to reproduce the tests on any machine.

## How the tests are executed

TODO

## Reference

* TODO How to launch the tests for an environment
* TODO How to switch the standard output on