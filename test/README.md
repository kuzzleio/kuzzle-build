# Setup.sh test developer's handbook

Setup.sh tests are performed by [expect](https://linux.die.net/man/1/expect), a linux command
that allows to spawn a program, interact with by sending input to it and doing assertions on
its output.

The aim of the the testing suite is the following:

* cover the maximum code surface of the setup.sh script;
* test the script in many Linux-type environments (Ubuntu, Debian, RedHat, Fedora...);
* enable the developer to reproduce the tests on any machine.

## How the tests are executed

The `setup.sh` script is tested against a whole set of Linux distributions.
The `test/run.sh` script starts a test suite for each distribution by calling the 
`test/test-setup.sh <distribution-name>` script . Each test suite starts a Docker
container from a clean image corresponding to the tested distribution. This container stays
alive during the rollout of the whole test suite.
Each test case executes the `/test/setupsh.should` script (in the Docker container) that 
spawns `setup.sh` and makes assumptions on the expected output and exit value.
Before each test case, a setup phase is performed in order to prepare the environment for the
incoming test. This is commonly done via the scripts in `test/fixtures-setupsh/*`. These
scripts are in charge of preparing the environment no-matter the distribution they are running
onto (for example, they are able to detect whether to install a package via apt-get or yum).

This can be resumed as the following

* The host machine (your dev computer or Travis) launches all the tests via `test/run.sh`,
    * which launches one test suite per distribution via `test/test-setup.sh <distribution>`,
        * which spawns one `setup.sh` script per test case via `test/setupsh.should <test_title> <expected_string> <expected_exit_value>`

The test suites are fail-fast: as soon as one case fails, the whole suite returns 1.

## Environment Variables Reference

When calling `test/run.sh` we can set environment variables to modify the script behavior

* `SHOW_DEBUG` - if set to anything, shows the output of the setup, teardown and setup.sh call
  for each test.
* `COMPOSE_HTTP_TIMEOUT` - can be se to the number of seconds the docker client waits for a
  socket to open on a container.