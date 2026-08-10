---
layout: default
title: Running Tests
parent: Ruby Harness
nav_order: 3
---

# Running Tests

`run_tests` runs the project's test suite and returns **structured results** —
summary counts plus per-test file/line/message for failures — never raw
terminal output. Agents get everything they need in one call and can rerun
just the failures.

```ruby
tool = Ask::Ruby::Harness::Tools::RunTests.new
tool.call
```

Returns, for example: `{ framework: "minitest", command: "bundle exec rake test", exit_status: 1, summary: { run: 24, failures: 1, errors: 0, skips: 0 }, failed_tests: [{ file:, test_name:, line:, message: }], artifact: "tmp/test/.ask/last-test.log", next: "run_tests(failed_only: true)" }`.

## Runner detection

The tool detects how to run the suite from the project itself:

| Project looks like | Command |
|---|---|
| Has `bin/rails` | `bin/rails test [files]` |
| `Gemfile.lock` has rspec + a `spec/` dir | `bundle exec rspec [files] --format json` |
| Anything else (plain Ruby project) | `bundle exec rake test` |

## Parameters

| Param | What it does |
|---|---|
| `file` | Test file path(s) relative to the project root (comma-separated for multiple) |
| `name` | Test name pattern (minitest `--name` / rspec `-e`) |
| `failed_only` | Rerun only the previous run's failures |
| `timeout` | Max seconds before the run is killed and reported `timed_out` |

### Monorepos

Point `file:` into a subproject (a directory with its own Gemfile/Rakefile)
and the suite runs **there** — rake/rails resolve the subproject's tasks,
and artifacts live in the subproject too:

```ruby
tool.call(file: "ask-mcp/test/gemspec_test.rb")
# runs in ask-mcp/, not the monorepo root
```

## How structured results work

- **Minitest**: the gem ships a JSON reporter
  (`lib/minitest/ask_ruby_harness_plugin.rb`) that writes test name, class,
  source file/line, status, and a message head. Minitest 5 auto-discovers
  the plugin; minitest 6 (which dropped plugin auto-discovery and the `-r`
  option) gets it injected via `RUBYOPT` by absolute path. The reporter is
  inert unless the harness started the run (`ASK_TEST_JSON_PATH` set), so
  ordinary `rake test` / `rails test` runs are untouched.
- **RSpec**: uses the built-in JSON formatter (`--format json --out`).
- The full human-readable output always lands at
  `tmp/test/.ask/last-test.log`; the failure list persists at
  `tmp/test/.ask/last-failures.json` for `failed_only` reruns.

Test runs are spawned with the project's own bundle (bundler env stripped
from the parent) and their normal pool sizes (`RAILS_MAX_THREADS` is
stripped so a capped harness server doesn't leak into test children).
