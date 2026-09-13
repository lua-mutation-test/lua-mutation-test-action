# lua-mutation-test-action

> Find the bugs your tests miss — mutation testing for Lua and Neovim plugins, in CI.

GitHub Action for [lua-mutation-test](https://github.com/lua-mutation-test/lua-mutation-test). It downloads a pinned `lmut` binary from GitHub Releases, runs mutation testing against your Lua sources, and can fail the build when the mutation score drops below a threshold.

## Usage

Add to `.github/workflows/mutation.yml`:

```yaml
name: mutation

on:
  push:
    branches: [main]
  pull_request:

jobs:
  mutation:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6

      - name: Run mutation testing
        uses: lua-mutation-test/lua-mutation-test-action@v1
        with:
          path: lua
          test-command: busted
```

Example output in the job log:

```text
Mutation score: 87.5% (42 killed, 6 survived, 0 timed out)
Survived: lua/init.lua:42:5 — changed `==` to `~=`
```

## Inputs

| Input | Description | Default |
| ----- | ----------- | ------- |
| `version` | Version of `lua-mutation-test` to install (e.g. `0.1.0`). | `latest` |
| `path` | File or directory to mutate. | `.` |
| `test-command` | Command run against each mutant (e.g. `busted`, `lux test`). Overrides config file. | `""` |
| `config` | Path to `.lua-mutation-test.toml` / `.json` config file. | `""` (auto-discovered) |
| `fail-under` | Fail the step if mutation score is below this percent (0–100). `0` disables the gate. | `0` |
| `timeout` | Per-mutant test timeout in seconds. Overrides config file. | `""` |
| `args` | Extra args passed through to `lmut run` (e.g. `--report-format json`). | `""` |

## Outputs

| Output | Description |
| ------ | ----------- |
| `mutation-score` | Mutation score percent (e.g. `87.5`). |
| `killed` | Number of killed mutants. |
| `survived` | Number of survived mutants. |

## Examples

### Pin a version and gate on score

```yaml
- uses: lua-mutation-test/lua-mutation-test-action@v1
  with:
    version: 0.1.0
    path: lua
    test-command: busted
    fail-under: 80
```

### Use a config file

```yaml
- uses: lua-mutation-test/lua-mutation-test-action@v1
  with:
    path: lua
    config: .lua-mutation-test.toml
    fail-under: 80
```

The config file holds the same options as the CLI — see the [main repo](https://github.com/lua-mutation-test/lua-mutation-test#configuration) for `test_command`, `timeout`, `source_globs`, operator excludes, and report formats.

### Emit a JSON report

```yaml
- uses: lua-mutation-test/lua-mutation-test-action@v1
  with:
    path: lua
    test-command: busted
    args: --report-format json --report-output mutation-report.json

- uses: actions/upload-artifact@v6
  with:
    name: mutation-report
    path: mutation-report.json
```

## How it works

1. Resolves `version` (`latest` follows the newest GitHub Release).
2. Downloads the pre-built `lmut` / `lua-mutation-test` binary for the runner platform and adds it to `PATH` — no Rust toolchain needed.
3. Runs `lmut run <path>` with your `test-command`, `config`, `timeout`, and `args`.
4. Parses the mutation score and exposes it as step outputs; fails if below `fail-under`.

Supported runners: `ubuntu-latest`, `macos-latest`. Windows support planned.

> Note: This action and the underlying tool are pre-`1.0` (ZeroVer `0.x`). Inputs, CLI flags, and behavior may change.

## Contributing

Contributions are welcome! This is an early-stage project — issues and PRs against `action.yml` and the docs are especially helpful.

See [CONTRIBUTING.md](CONTRIBUTING.md) when available, and the [main tool's contributing guide](https://github.com/lua-mutation-test/lua-mutation-test/blob/main/CONTRIBUTING.md) for the agentic workflow used in this org.

## License

Licensed under the [Apache License 2.0](LICENSE), matching [lua-mutation-test](https://github.com/lua-mutation-test/lua-mutation-test).
