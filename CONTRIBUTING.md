# Steps to follow before merging anything to `master`

Merging things to `master` triggers the CI process that publishes `docker-compose/kuzzle-docker-compose.yml`
and `setup.sh` right on the Kuzzle.io website. This is something that deserves caution.
This applies to any modification of the content of the repo as well as the repo name itself (as its URL is
referenced by other internal integrity-check tools).

It is mandatory to create branches from `1.x` (the development branch) so that the PRs are merged on it
instead of `master`. Then, when the team needs to update the published content, `1.x` can be merged to
`master` but a few operations must be performed to ensure that nothing is broken.

* Make sure that `setup.sh` is in sync with the Kuzzle Analytics proxy (http://analytics.kuzzle.io/) so that
the analytics still work.
* Make sure that New Relic probes are aware of the new version of `setup.sh`.
* Make sure that the alert mails are still properly pushed by the Analytics Proxy.
