# Specwrk
Run your [RSpec](https://github.com/rspec/rspec) examples across many processors and many nodes for a single build. Or just many processes on a single node. Speeds up your *slow* (minutes/hours not seconds) test suite by running multiple examples in parallel.

One CLI command to:

1. Start a queue server for your current build
2. Seed the queue server with all possible examples in the current project
3. Execute

## Install
Start by adding `specwrk` to your project or installing it.
```sh
$ bundle add specwrk -g development,test
```
```sh
$ gem install specwrk
```

## CLI

```sh
$ specwrk --help

Commands:
  specwrk seed [DIR]            # Seed the server with a list of specs for the run
  specwrk serve                 # Start a queue server
  specwrk start [DIR]           # Start a server and workers, monitor until complete
  specwrk version               # Print version
  specwrk work                  # Start one or more worker processes
```

### `specwrk start -c 8 spec/`
Intended for quick ad-hoc local host development or single-node CI runs. This command starts a queue server, seeds it with examples from the `spec/` directory, and starts `8` worker processes. It will report the ultimate success or failure.

```sh
$ start --help
Command:
  specwrk start

Usage:
  specwrk start [DIR]

Description:
  Start a server and workers, monitor until complete

Arguments:
  DIR                               # Relative spec directory to run against

Options:
  --uri=VALUE                       # HTTP URI of the server to pull jobs from. Overrides SPECWRK_SRV_URI, default: "http://localhost:5138"
  --key=VALUE, -k VALUE             # Authentication key clients must use for access. Overrides SPECWRK_SRV_KEY, default: ""
  --run=VALUE, -r VALUE             # The run identifier for this job execution. Overrides SPECWRK_RUN, default: "main"
  --timeout=VALUE, -t VALUE         # The amount of time to wait for the server to respond. Overrides SPECWRK_TIMEOUT, default: "5"
  --id=VALUE                        # The identifier for this worker. Default specwrk-worker(-COUNT_INDEX), default: "specwrk-worker"
  --count=VALUE, -c VALUE           # The number of worker processes you want to start, default: 1
  --output=VALUE, -o VALUE          # Directory where worker output is stored. Overrides SPECWRK_OUT, default: ".specwrk/"
  --seed-waits=VALUE, -w VALUE      # Number of times the worker will wait for examples to be seeded to the server. 1sec between attempts. Overrides SPECWRK_SEED_WAITS, default: "10"
  --port=VALUE, -p VALUE            # Server port. Overrides SPECWRK_SRV_PORT, default: "5138"
  --bind=VALUE, -b VALUE            # Server bind address. Overrides SPECWRK_SRV_BIND, default: "127.0.0.1"
  --group-by=VALUE                  # How examples will be grouped for workers; fallback to file if no timings are found. Overrides SPECWERK_SRV_GROUP_BY: (file/timings), default: "timings"
  --[no-]single-seed-per-run        # Only allow one seed per run. Useful for CI where many nodes may seed at the same time, default: false
  --[no-]verbose                    # Run in verbose mode. Default false., default: false
  --help, -h                        # Print this help
```

### `specwrk serve`
Only start the server process. Intended for use in CI pipelines.

```sh
$ specwrk serve --help
Command:
  specwrk serve

Usage:
  specwrk serve

Description:
  Start a queue server

Options:
  --port=VALUE, -p VALUE            # Server port. Overrides SPECWRK_SRV_PORT, default: "5138"
  --bind=VALUE, -b VALUE            # Server bind address. Overrides SPECWRK_SRV_BIND, default: "127.0.0.1"
  --key=VALUE, -k VALUE             # Authentication key clients must use for access. Overrides SPECWRK_SRV_KEY, default: ""
  --output=VALUE, -o VALUE          # Directory where worker output is stored. Overrides SPECWRK_OUT, default: ".specwrk/"
  --group-by=VALUE                  # How examples will be grouped for workers; fallback to file if no timings are found. Overrides SPECWERK_SRV_GROUP_BY: (file/timings), default: "timings"
  --[no-]single-seed-per-run        # Only allow one seed per run. Useful for CI where many nodes may seed at the same time, default: false
  --[no-]verbose                    # Run in verbose mode. Default false., default: false
  --[no-]single-run                 # Act on shutdown requests from clients. Default: false., default: false
  --help, -h                        # Print this help
```

### `specwrk seed spec/`
Seed the configured server with examples from the `spec/` directory. Intended for use in CI pipelines.

```sh
specwrk seed --help
Command:
  specwrk seed

Usage:
  specwrk seed [DIR]

Description:
  Seed the server with a list of specs for the run

Arguments:
  DIR                               # Relative spec directory to run against

Options:
  --uri=VALUE                       # HTTP URI of the server to pull jobs from. Overrides SPECWRK_SRV_URI, default: "http://localhost:5138"
  --key=VALUE, -k VALUE             # Authentication key clients must use for access. Overrides SPECWRK_SRV_KEY, default: ""
  --run=VALUE, -r VALUE             # The run identifier for this job execution. Overrides SPECWRK_RUN, default: "main"
  --timeout=VALUE, -t VALUE         # The amount of time to wait for the server to respond. Overrides SPECWRK_TIMEOUT, default: "5"
  --help, -h                        # Print this help
```

### `specwrk work -c 8`
Starts `8` worker processes which will pull examples off the seeded server. Intended for use in CI pipelines.

```sh
$ specwrk work --help
Command:
  specwrk work

Usage:
  specwrk work

Description:
  Start one or more worker processes

Options:
  --id=VALUE                        # The identifier for this worker. Overrides SPECWRK_ID. If none provided one in the format of specwrk-worker-8_RAND_CHARS-COUNT_INDEX will be used
  --count=VALUE, -c VALUE           # The number of worker processes you want to start, default: 1
  --output=VALUE, -o VALUE          # Directory where worker output is stored. Overrides SPECWRK_OUT, default: ".specwrk/"
  --seed-waits=VALUE, -w VALUE      # Number of times the worker will wait for examples to be seeded to the server. 1sec between attempts. Overrides SPECWRK_SEED_WAITS, default: "10"
  --uri=VALUE                       # HTTP URI of the server to pull jobs from. Overrides SPECWRK_SRV_URI, default: "http://localhost:5138"
  --key=VALUE, -k VALUE             # Authentication key clients must use for access. Overrides SPECWRK_SRV_KEY, default: ""
  --run=VALUE, -r VALUE             # The run identifier for this job execution. Overrides SPECWRK_RUN, default: "main"
  --timeout=VALUE, -t VALUE         # The amount of time to wait for the server to respond. Overrides SPECWRK_TIMEOUT, default: "5"
  --help, -h                        # Print this help
```

## Configuring your test environment
If you test suite tracks state, starts servers, etc. and you plan on running many processes on the same node, you'll need to make
adjustments to avoid conflicting port usage or database/state mutations.

`specwrk` workers will have `TEST_ENV_NUMBER={i}` set to help you configure approriately.

### Rails
Rails has had easy multi-process test setup for a while now by creating unique test databases per process. For my rails v7.2 app which uses PostgreSQL and Capyabara, I made these changes to my `spec/rails_helper.rb`:

```diff
++ if ENV["TEST_ENV_NUMBER"]
++   ActiveRecord::TestDatabases.create_and_load_schema(
++     ENV["TEST_ENV_NUMBER"].to_i, env_name: ActiveRecord::ConnectionHandling::DEFAULT_ENV.call
++   )
++ end
-- Capybara.server_port = 5550
++ Capybara.server_port = 5550 + ENV.fetch("TEST_ENV_NUMBER", "1").to_i
++ Capybara.always_include_port = true
-- ActiveRecord::Migration.maintain_test_schema!
++ ActiveRecord::Migration.maintain_test_schema! unless ENV["SPECWRK_SEED"]
```

YMMV, but please submit an issue if your setup required more configuration.

## CI
Run `specwrk` in CI in either a single-node or multi-node configuration.

### Single-node, multi-process
Single-node, multi-process works best when you only have a single node running tests, but that node has many unused CPUs. This is similar to running `specwrk` locally with `bundle exec specwrk start spec/` which spins up a local server, seeds the server with examples that need to be run, and then spawns child worker processes which execute those examples in parallel.

Make sure to persist `$SPECWRK_OUT/report.json` between runs so that subsequent run queues can be optimized.

[GitHub Actions Example](https://github.com/danielwestendorf/specwrk/blob/main/.github/workflows/specwrk-single-node.yml)

[CircleCI Example](https://github.com/danielwestendorf/specwrk/blob/main/.circleci/config.yml) (specwrk-single-node job)

### Multi-node, multi-process
Multi-node, multi-process works best when have many nodes running tests. This distributes the test execution across the nodes until the queue is for the run is empty, optimizing for slowest specs first. This distributes test execution across all nodes evenly(-ish).

To accomplish this, a central queue server is required, examples must be explicitly seeded, and workers explicitly started.

1. Start a centralized queue server (see [Running a persistent Queue Server](#running-a-persistent-queue-server)) 
2. Seed the server with the specs for the current `SPECWWRK_RUN` pointed at your central server
3. Execute `specwrk work` for the given process count, for the current `SPECWRK_RUN`, pointed at your central server

[GitHub Actions Example](https://github.com/danielwestendorf/specwrk/blob/main/.github/workflows/specwrk-multi-node.yml)

[CircleCI Example](https://github.com/danielwestendorf/specwrk/blob/main/.circleci/config.yml) (see specwrk-multi-node-prepare, specwrk-multi-node jobs)


## Running a persistent Queue Server
Start a persistent Queue Server given one of the following methods
- The explicit ruby command `bundle exec specwrk serve --port $PORT`
- Via [docker image](https://hub.docker.com/repository/docker/danielwestendorf/specwrk-server/general): `docker run -e PORT=5139 -p 5139:5139 docker.io/danielwestendorf/specwrk-server:latest`
- By mounting the app as an Rack app (see `config.ru`)

### Configuring your Queue Server
- Secure your server with a key either with the `SPECWRK_SRV_KEY` environment variable or `--key` CLI option
- Configure the server output to be a persisted volume so your timings survive between restarts with  the `SPECWRK_OUT` environment variable or `--out` CLI option 

See [specwrk serve --help](#specwrk-serve) for all possible configuration options.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/dwestendorf/specwrk.

## License

The gem is available as open source under the terms of the [LGLPv3 License](http://www.gnu.org/licenses/lgpl-3.0.html).
