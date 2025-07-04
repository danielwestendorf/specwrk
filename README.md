# Specwrk
Run your [RSpec](https://github.com/rspec/rspec) examples across many processors and many nodes for a single build. Or just many processes on a single node. Speeds up your *slow* (minutes/hours not seconds) test suite by running multiple examples in parallel.

One CLI command to:

1. Start a queue server for your current build
2. Seed the queue server with all possible examples in the current project
3. Execute

## Install
Start by adding specwrk to your project or installing it.
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
Indended for quick-adhoc runs in development. This command starts a queue server, seeds it with examples from the `spec/` directory, and starts `8` worker processes. It will report the ultimate success or failure.

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
  --uri=VALUE                       # HTTP URI of the server to pull jobs from. Overrides SPECWRK_SRV_PORT. Default 5138., default: "https://localhost:5138"
  --key=VALUE, -k VALUE             # Authentication key clients must use for access. Overrides SPECWRK_SRV_KEY. Default ''., default: ""
  --run=VALUE, -r VALUE             # The run identifier for this job execution. Overrides SPECWRK_RUN. Default main., default: "main"
  --timeout=VALUE, -t VALUE         # The amount of time to wait for the server to respond. Overrides SPECWRK_TIMEOUT. Default 5., default: "5"
  --id=VALUE                        # The identifier for this worker. Default specwrk-worker(-COUNT_INDEX)., default: "specwrk-worker"
  --count=VALUE, -c VALUE           # The number of worker processes you want to start. Default 1., default: 1
  --output=VALUE, -o VALUE          # Directory where worker output is stored. Overrides SPECWRK_OUT. Default '.specwrk/'., default: ".specwrk/"
  --port=VALUE, -p VALUE            # Server port. Overrides SPECWRK_SRV_PORT. Default 5138., default: "5138"
  --bind=VALUE, -b VALUE            # Server bind address. Overrides SPECWRK_SRV_BIND. Default 127.0.0.1., default: "127.0.0.1"
  --group-by=VALUE                  # How examples will be grouped for workers; fallback to file if no timings are found. Overrides SPECWERK_SRV_GROUP_BY. Default timings.: (file/timings), default: "timings"
  --[no-]single-run                 # Act on shutdown requests from clients. Default: false., default: false
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
  --port=VALUE, -p VALUE            # Server port. Overrides SPECWRK_SRV_PORT. Default 5138., default: "5138"
  --bind=VALUE, -b VALUE            # Server bind address. Overrides SPECWRK_SRV_BIND. Default 127.0.0.1., default: "127.0.0.1"
  --key=VALUE, -k VALUE             # Authentication key clients must use for access. Overrides SPECWRK_SRV_KEY. Default ''., default: ""
  --output=VALUE, -o VALUE          # Directory where worker output is stored. Overrides SPECWRK_OUT. Default '.specwrk/'., default: ".specwrk/"
  --group-by=VALUE                  # How examples will be grouped for workers; fallback to file if no timings are found. Overrides SPECWERK_SRV_GROUP_BY. Default timings.: (file/timings), default: "timings"
  --[no-]single-run                 # Act on shutdown requests from clients. Default: false., default: false
  --[no-]verbose                    # Run in verbose mode. Default false., default: false
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
  --uri=VALUE                       # HTTP URI of the server to pull jobs from. Overrides SPECWRK_SRV_PORT. Default 5138., default: "https://localhost:5138"
  --key=VALUE, -k VALUE             # Authentication key clients must use for access. Overrides SPECWRK_SRV_KEY. Default ''., default: ""
  --run=VALUE, -r VALUE             # The run identifier for this job execution. Overrides SPECWRK_RUN. Default main., default: "main"
  --timeout=VALUE, -t VALUE         # The amount of time to wait for the server to respond. Overrides SPECWRK_TIMEOUT. Default 5., default: "5"
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
  --id=VALUE                        # The identifier for this worker. Default specwrk-worker(-COUNT_INDEX)., default: "specwrk-worker"
  --count=VALUE, -c VALUE           # The number of worker processes you want to start. Default 1., default: 1
  --output=VALUE, -o VALUE          # Directory where worker output is stored. Overrides SPECWRK_OUT. Default '.specwrk/'., default: ".specwrk/"
  --uri=VALUE                       # HTTP URI of the server to pull jobs from. Overrides SPECWRK_SRV_PORT. Default 5138., default: "https://localhost:5138"
  --key=VALUE, -k VALUE             # Authentication key clients must use for access. Overrides SPECWRK_SRV_KEY. Default ''., default: ""
  --run=VALUE, -r VALUE             # The run identifier for this job execution. Overrides SPECWRK_RUN. Default main., default: "main"
  --timeout=VALUE, -t VALUE         # The amount of time to wait for the server to respond. Overrides SPECWRK_TIMEOUT. Default 5., default: "5"
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
```

## CI
1 server N nodes with N processes => 🏎️

TODO!

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/dwestendorf/specwrk.

## License

The gem is available as open source under the terms of the [LGLPv3 License](http://www.gnu.org/licenses/lgpl-3.0.html).
