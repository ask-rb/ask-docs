---
layout: default
title: Sandbox Providers
parent: Core Components
nav_order: 3
---


## Quick Start

```ruby
require "ask-sandbox-providers"

# Default: Local (subprocess + rlimits)
result = Ask::Sandbox.provider.call(["ruby", "-e", "puts 1+1"])
result.stdout     # => "2
"
result.exit_code  # => 0

# String commands → shell execution
Ask::Sandbox.provider.call("ls -la | head -5")

# Array commands → execve-style (no shell)
Ask::Sandbox.provider.call(["ruby", "-e", "puts ENV['HOME']"])
```

### Switch Provider

```ruby
Ask::Sandbox.provider = :docker
Ask::Sandbox.provider = Ask::Sandbox::Docker.new(
  image: "ruby:3.4-alpine",
  memory: "256m",
  network: false
)

Ask::Sandbox.provider = :daytona
Ask::Sandbox.provider = Ask::Sandbox::Daytona.new(
  api_key: ENV["DAYTONA_API_KEY"]
)

Ask::Sandbox.provider = :cloudflare
Ask::Sandbox.provider = Ask::Sandbox::Cloudflare.new(
  worker_url: "https://sandbox-proxy.my-worker.workers.dev",
  auth_token: ENV["CLOUDFLARE_SANDBOX_TOKEN"]
)
```

---

## `Ask::Sandbox::Result`

```ruby
Result = Data.define(:stdout, :stderr, :exit_code, :timed_out)
result.success?  # exit_code == 0
```

---

## Providers

### Local (Default)

Process-level isolation via `Process.spawn` with `pgroup: true`.

**Security measures:**
- Process group isolation — kills entire tree on timeout
- `Process.setrlimit`: CPU (10s/30s), address space (2GB), processes (50), file size (10MB), FDs (200)
- Temp directory via `Dir.mktmpdir`
- Environment sanitization — strips `BUNDLE_*`, `GEM_*`, `RUBYOPT`, `RUBYLIB`; preserves `ASK_*`
- Output truncated at 100KB per stream

### Docker

Full container isolation via the `docker` CLI.

**Constructor:**
```ruby
Docker.new(
  image: "ruby:3.4-alpine",   # Docker image
  memory: "512m",               # Memory limit
  cpus: 1.0,                    # CPU limit
  network: false,               # Block network egress
  read_only: true,              # Read-only rootfs
  cap_drop: "ALL",              # Drop all capabilities
  user: nil,                    # Container default user
  timeout: 30,                  # Default timeout
  remove: true                  # Auto-cleanup
)
```

**Flags passed to `docker run`:**
- `--read-only` — read-only root filesystem
- `--cap-drop ALL` — no Linux capabilities
- `--security-opt no-new-privileges`
- `--network none` — no network egress
- `--pids-limit 100`
- `--memory`, `--cpus` — resource limits

### Daytona

Remote sandbox via the official [`daytona`](https://rubygems.org/gems/daytona) gem.
The gem is loaded lazily — install it only if you use this provider.

```ruby
Daytona.new(
  api_key: nil,       # Falls back to ENV["DAYTONA_API_KEY"] or Ask::Auth.lookup
  server_url: nil,    # Defaults to Daytona SDK default
  image: nil,         # Sandbox image (default: "ruby:3.4")
  timeout: 120        # Sandbox boot can take time
)
```

### Cloudflare

Edge sandbox via a user-deployed proxy Worker wrapping `@cloudflare/sandbox`.

```ruby
Cloudflare.new(
  worker_url: nil,    # Falls back to ENV["CLOUDFLARE_SANDBOX_WORKER_URL"]
  auth_token: nil,    # Falls back to ENV["CLOUDFLARE_SANDBOX_AUTH_TOKEN"]
  timeout: 60
)
```

**Requirements:**
1. Deploy a [proxy Worker](https://developers.cloudflare.com/sandbox/) that wraps `@cloudflare/sandbox`
2. Set `CLOUDFLARE_SANDBOX_WORKER_URL` or pass `worker_url:`

---

## Links

- **Source:** [github.com/ask-rb/ask-sandbox-providers](https://github.com/ask-rb/ask-sandbox-providers)
- **Rubygems:** [rubygems.org/gems/ask-sandbox-providers](https://rubygems.org/gems/ask-sandbox-providers)
- **Changelog:** [CHANGELOG.md](https://github.com/ask-rb/ask-sandbox-providers/blob/master/CHANGELOG.md)
