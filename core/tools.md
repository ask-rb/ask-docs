---
layout: default
title: Tools & Execution
parent: Core Components
nav_order: 2
---


## Quick Start

```ruby
require "ask-tools"

class Greeter < Ask::Tool
  description "Greets a person by name"
  param :name, type: :string, desc: "The person's name", required: true

  def execute(name:)
    Ask::Result.ok(data: "Hello, #{name}!")
  end
end

tool = Greeter.new
tool.name          # => "greeter"
tool.description   # => "Greets a person by name"

result = tool.call(name: "World")
result.ok?         # => true
result.output      # => "Hello, World!"
```

---

## `Ask::Tool` — Base Class

Subclass `Ask::Tool` to define a tool that an LLM can call.

### Class DSL

| Method | Description |
|--------|-------------|
| `description(text)` | Sets/retrieves the tool's description. Alias: `desc` |
| `name(text)` | Override the auto-derived tool name. Call with no argument returns the class path |
| `param(name, type:, desc:, required:)` | Declares a parameter. `type` must be a valid JSON Schema type |

### Instance Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `name` | `String` | Returns custom name if set via `name ""` DSL, otherwise auto-derived from class name (CamelCase → snake_case, strips `_tool`) |
| `description` | `String?` | The tool's description |
| `parameters` | `Hash{Symbol => Parameter}` | Declared parameter definitions |
| `call(args = {})` | `Ask::Result` | Normalizes args, validates, delegates to `execute` |
| `execute(**args)` | `Ask::Result` | **Override this.** Implement the tool's logic |
| `params_schema` | `Hash?` | JSON Schema hash for LLM function-calling APIs |
| `tool_definition` | `Hash` | Full tool definition with name, description, input_schema |

### Error Handling

- **`Ask::Tool::Halt`** — Raise inside `execute` to stop the conversation loop.
- **`StandardError`** — Caught by `call` and returned as error `Ask::Result`.

### Human Approval

{: .new }
> New in ask-tools 0.6.0

Declare that a tool requires human approval before it runs. Combined with an
`Ask::Agent::ApprovalQueue` (ask-agent 0.27.0), calls to the tool are queued
instead of executed — the agent gets a pending result and continues, and the
tool runs only after a human approves it.

```ruby
class SendEmail < Ask::Tool
  approval_required true
  def execute(to:, body:) ... end
end

class Ping < Ask::Tool
  approval_required true
  auto_approvable true   # may be auto-approved when a user rule enables it
  def execute ... end
end
```

- `approval_required` — gates the tool behind human approval.
- `auto_approvable` — per-action verdict only; the session's user rule is
  still the binding gate (dual signal).
- Instance predicates: `tool.approval_required?`, `tool.auto_approvable?`.
- Flags default to false and are **not** inherited by subclasses.

See [The Agent Loop — Tool Approval](agent.md#tool-approval-human-in-the-loop).

---

## `Ask::Result` — Standardized Return Value

`Ask::Result` lives in ask-core (the zero-dependency foundation) and is the
single result type for the whole ecosystem — providers, tools, and agents all
return it. This is the same class you get from `require "ask"`.

```ruby
require "ask-tools"

# Factories
ok = Ask::Result.ok(data: "output")
err = Ask::Result.error(message: "fail")

# Attributes
ok.ok?         # => true
ok.output      # => "output"
ok.error       # => nil
ok.metadata    # => {}
ok.to_s        # => "output"
ok.to_h        # => {ok: true, output: "output", error: nil, metadata: {}}

err.ok?        # => false
err.error      # => "fail"
```

---

## `Ask::Tools` — Registry & Discovery

```ruby
require "ask-tools"

class PingTool < Ask::Tool
  description "Pings"
  def execute
    Ask::Result.ok(data: "pong")
  end
end

Ask::Tools.register(PingTool)
Ask::Tools.all.map(&:name)      # => ["ping"]
Ask::Tools["ping"].call.output  # => "pong"
Ask::Tools.count                # => 1
```

`discover` auto-registers every loaded `Ask::Tool` subclass; `clear` empties the registry:

```ruby
require "ask-tools"

Ask::Tools.discover
Ask::Tools.clear
Ask::Tools.count  # => 0
```

Thread-safe via `Monitor`.

---

## Writing Custom Tools

This is all `ask-tools` — `gem "ask-tools"` (it's already a dependency of `ask-agent` if you're building an agent).

```ruby
class SearchTool < Ask::Tool
  description "Searches a knowledge base"
  param :query, type: :string, desc: "Search query", required: true
  param :limit, type: :integer, desc: "Max results", required: false

  def execute(query:, limit: 10)
    results = perform_search(query, limit)
    Ask::Result.ok(data: results)
  rescue SearchError => e
    Ask::Result.error(message: e.message)
  end
end
```

---

## Links

- **Source:** [github.com/ask-rb/ask-tools](https://github.com/ask-rb/ask-tools)
- **Issues:** [github.com/ask-rb/ask-tools/issues](https://github.com/ask-rb/ask-tools/issues)
- **Rubygems:** [rubygems.org/gems/ask-tools](https://rubygems.org/gems/ask-tools)

---

## ask-tools-shell

**Shell, filesystem, and code execution tools.** Ships 9 tools every agent needs: Bash, Read, Write, Edit, Glob, Grep, Code, Repl, and ApplyPatch.

```ruby
gem "ask-tools-shell"
```

### Quick Start

```ruby
require "ask-tools-shell"

Ask::Tools::Shell.all.map(&:name)
# => ["bash", "read", "write", "edit", "glob", "grep", "code", "repl", "apply_patch"]

Ask::Tools::Bash.new.call(command: "echo hello")
Ask::Tools::Read.new.call(path: "/etc/hosts")
Ask::Tools::Code.new.call(code: "puts RUBY_VERSION")
```

The tool classes live directly under `Ask::Tools` (`Ask::Tools::Bash`, `Ask::Tools::Read`, ...). The `Ask::Tools::Shell` module is the registry: `Shell::TOOLS` lists all nine classes and `Shell.all` returns instances.

### Sandbox Configuration (v0.2.0+)

Both `Bash` and `Code` tools use `Ask::Sandbox.provider` from the
`ask-sandbox-providers` gem. By default, execution happens in a local
subprocess with resource limits. To enable stronger isolation:

```ruby
require "ask-sandbox-providers"

# Docker containers
Ask::Sandbox.provider = Ask::Sandbox::Docker.new(
  image: "ruby:3.4-alpine",
  memory: "256m",
  network: false
)

# Remote sandboxes via Daytona
Ask::Sandbox.provider = Ask::Sandbox::Daytona.new(
  api_key: ENV["DAYTONA_API_KEY"]
)

# Cloudflare Workers sandbox
Ask::Sandbox.provider = Ask::Sandbox::Cloudflare.new(
  worker_url: "https://sandbox-proxy.my-worker.workers.dev"
)
```

When a command times out, `Bash` and `Code` return `Ask::Result.error` instead
of `Ask::Result.ok`.

### Available Tools

| Tool | Params | Description |
|------|--------|-------------|
| **Bash** | `command` (req), `timeout`, `workdir` | Execute shell commands in a sandboxed temp dir. Returns stdout, stderr, exit_code, timed_out. Output truncated to 100KB |
| **Read** | `path` (req), `offset`, `limit` | Read files with line numbers or list directories. Default limit 2000 lines |
| **Write** | `path` (req), `content` (req) | Write to files, creating parent dirs automatically. Max 500KB |
| **Edit** | `path` (req), `old_string` (req), `new_string` (req), `replace_all` | Replace exact text. Single replacement by default |
| **Glob** | `pattern` (req), `path` | Find files matching glob. Max 1000 results, sorted newest first |
| **Grep** | `pattern` (req), `path`, `include` | Regex search in files. Max 100 matches, 500 chars/line. Skips .git, node_modules, etc. |
| **Code** | `code` (req) | Execute Ruby in a subprocess. Uses available gems, passes env through |
| **Repl** | `code` (req), `session`, `reset` | Evaluate Ruby in a persistent session. State survives across calls — see below |
| **ApplyPatch** | `patchText` (req) | Edit files using a unified diff format. Precise, multi-file edits in one call |

### Repl — Persistent Ruby Sessions (v0.4.0+)

Where `Code` spawns a fresh `ruby -e` per call, `Repl` keeps a long-lived
plain-ruby kernel subprocess and evaluates every snippet into the same
binding. Locals, `require`s, and defined methods survive between calls, so an
agent composes capabilities as code against a working environment instead of
re-bootstrapping it each time:

```ruby
repl = Ask::Tools::Repl.new

repl.call(code: 'require "json"; data = JSON.parse(%q({"a": 1}))')
repl.call(code: "data['a'] + 1")        # => 2 — `data` still exists
repl.call(code: "def double(x); x * 2; end")
repl.call(code: "double(21)")           # => 42
```

- **Sessions** are named and shared process-wide (`session:` param, default
  `"default"`) — any tool instance reaching the same name shares state.
  Sessions are isolated subprocesses, so a crash in one cannot affect another.
- **`reset: true`** discards a session's state before evaluating; use it when
  a session is corrupted or you want a clean slate. `Repl.close_session(name)`
  and `Repl.close_all` close sessions explicitly (kernels also clean up at
  exit).
- **Timeouts** — a single evaluation is capped at `Repl.eval_timeout` (default
  30s). A timeout kills the session (state is lost) and the next call respawns
  it fresh. Idle sessions recycle after `Repl.idle_timeout` (default 300s).
  If a session dies unexpectedly, the next call respawns it and retries once
  transparently.
- **Environment** — the kernel is plain ruby: bundler env vars (RUBYOPT,
  GEM_HOME, ...) are removed at spawn, so it sees globally installed gems
  regardless of the agent's own Gemfile. Unlike `Bash`/`Code`, it is not
  sandboxed — treat it as durable control environment, not a security boundary.

### Links

- **Source:** [github.com/ask-rb/ask-tools-shell](https://github.com/ask-rb/ask-tools-shell)
- **Rubygems:** [rubygems.org/gems/ask-tools-shell](https://rubygems.org/gems/ask-tools-shell)

---

## Sub-Agents as Tools

To delegate a task to a sub-agent, use `Ask::Agent::SubAgent` from ask-agent. It satisfies the tool duck type (`name`, `description`, `params_schema`, `call`), so it plugs straight into a session's tools array:

```ruby
search = Ask::Agent::SubAgent.new(
  name: "web_search",
  description: "Search the web for current information",
  model: "deepseek-v4-flash",
  tools: [Ask::Tools::WebSearch],
  system_prompt: "You are a research assistant."
)

session = Ask::Agent::Session.new(model: "deepseek-v4-flash", tools: [search])
```

When the coordinator calls it, a fresh session runs with its own model, tools, and instructions. See [Sub-Agent Delegation](/ask-docs/core/agent#sub-agent-delegation) for the full picture.

---

## ask-web-search

**Web search tool powered by SearXNG.** Provides a single tool — `Ask::Tools::WebSearch` — that searches the web via a local SearXNG instance and returns formatted results for LLM consumption.

```ruby
gem "ask-web-search"
```

### Quick Start

<!-- docs-example: not-verified -->
```ruby
require "ask/web_search"

tool = Ask::Tools::WebSearch.new
result = tool.execute(query: "ruby programming language")
puts result
```

`execute` returns a numbered, markdown-like string of results. The exact
output depends on your SearXNG instance and the live search results, so it
varies per query — run it against your own instance to see it.

### Configuration

Point to your SearXNG instance via the `SEARXNG_URL` environment variable:

```sh
export SEARXNG_URL=http://localhost:8888
```

Defaults to `http://localhost:8888`.

Start SearXNG with Docker:

```sh
docker run -d --name searxng -p 8888:8080 searxng/searxng
```

### Usage with Chat

```ruby
chat = Ask::Agent::Chat.new(
  model: "deepseek-v4-flash",
  tools: [Ask::Tools::WebSearch.new]
)

chat.ask("What is the population of Tokyo? Search the web.")
```

### Usage with Agent

```ruby
session = Ask::Agent::Session.new(
  model: "deepseek-v4-flash",
  tools: [Ask::Tools::WebSearch]
)

session.run("Find recent news about Mars exploration.")
```

### Available Tools

| Tool | Params | Description |
|------|--------|-------------|
| **WebSearch** | `query` (req) | Searches the web via SearXNG. Returns numbered results with title, URL, and content. Includes infobox results. Deduplicates by URL |

### API

| Method | Returns | Description |
|--------|---------|-------------|
| `execute(query:)` | `String` | Searches the web and returns formatted results, or `"No results found."` |

### Output Format

Results are returned as a numbered markdown-like string:

```
1. Ruby — A Programmer's Best Friend
   https://www.ruby-lang.org
   Ruby is a dynamic, open-source programming language...

2. Ruby on Rails
   https://rubyonrails.org
   Rails is a web application framework...
```

### Development

```bash
bundle install
bundle exec rake test
```

Requires a running SearXNG instance for the integration test.

### Dependencies

- **Runtime:** `ask-tools >= 0.1`
- **No Rails or HTTP framework dependencies** — works in a script or a full Rails app

### Links

- **Source:** [github.com/ask-rb/ask-web-search](https://github.com/ask-rb/ask-web-search)
- **Rubygems:** [rubygems.org/gems/ask-web-search](https://rubygems.org/gems/ask-web-search)
