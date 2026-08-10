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
# => ["bash", "read", "write", "edit", "glob", "grep", "code", "apply_patch", "repl"]

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
| **Read** | `path` (req), `offset`, `limit` | Read files with line numbers or list directories. Bounded to 2000 lines / 128 KB with precomputed resume hints; one-line answers for empty, binary, and PDF files; refuses device files; repairs filenames (did-you-mean) — see below |
| **Write** | `path` (req), `content` (req) | Write to files, creating parent dirs automatically. Max 500KB. Refuses to overwrite files only partially read |
| **Edit** | `path` (req), `old_string` (req), `new_string` (req), `replace_all` | Replace exact text. Single replacement by default |
| **Glob** | `pattern` (req), `path` | Find files matching glob. Max 1000 results, sorted newest first |
| **Grep** | `pattern` (req), `path`, `include` | Regex search in files. Max 100 matches, 500 chars/line. Skips .git, node_modules, etc. |
| **Code** | `code` (req) | Execute Ruby in a subprocess. Uses available gems, passes env through |
| **Repl** | `code` (req), `session`, `reset` | Evaluate Ruby in a persistent session. State survives across calls — see below |
| **ApplyPatch** | `patchText` (req) | Edit files using a unified diff format. Precise, multi-file edits in one call |

### Read — Engineered for Token Budgets (v0.5.0+)

Reads are the bill for building context — every edit starts with one, every
grep hit becomes one. So `Read` treats every decision inside the tool as a
token-budget decision, and the expensive failure modes get designed out:

- **Three ceilings, not one** — a 2000-line window bounds the long file, a
  128 KB byte budget bounds the wide file, and a 2000-char per-line clamp
  stops a minified bundle from eating the whole budget in one line.
- **Truncation is a fact, not an error** — reads that stop short return `ok`
  with a precomputed resume offset. The model never does pagination
  arithmetic (which it gets wrong often enough to cost another round trip).
- **Silence is the most expensive thing a tool can return** — an empty
  result is indistinguishable from a broken tool, so every dead end names
  its own recovery: empty files, past-EOF offsets, binary files (a mime
  note, never garbage bytes), and PDFs (a pdftotext hint).
- **Reads stream** — a 400 MB log costs one bounded read, not one load.
- **Inputs are repaired, not bounced** — `"2000"` and `2.0` are accepted;
  `"2abc"` and `1.5` are rejected instead of silently reading the wrong
  window.
- **Some paths never open** — `/dev/zero` and friends are refused by name
  before any I/O; a read that hangs is a denial of service.
- **Filenames are adversarial** — NFD/NFC, narrow no-break spaces, and
  curly quotes are invisible to the model, so the tool retries the variants
  and then offers "did you mean?" (substring + bounded Levenshtein ≤ 2 —
  the thing that catches `AGENT.md` → `AGENTS.md`).
- **Re-reads of unchanged files return a stub** — the content is already in
  context. The stub is consumed on use (a stale hit is catastrophic), only
  fires for complete reads, and has a kill switch
  (`ASK_TOOLS_SHELL_READ_NO_CACHE=1`).
- **A ledger of what the model has seen** — `Read` records partial views,
  and `Write` refuses to overwrite a partially-read unchanged file, because
  overwriting would silently destroy the part it never saw.

A truncated read carries its resume offset in the result:

```ruby
require "ask-tools-shell"

File.write("app.log", (1..50).map { |i| "line #{i} " + "x" * 30 }.join("\n"))
tool = Ask::Tools::Read.new
tool.byte_budget = 500
first = tool.call(path: "app.log")
first.metadata.slice(:truncated, :partial_view, :resume_offset)
# => {truncated: true, partial_view: true, resume_offset: 12}

first.output.lines.last
# => "... (more lines) — resume with offset=12"
```

And the resume offset actually works — pass it straight back in:

```ruby
require "ask-tools-shell"

File.write("app.log", (1..50).map { |i| "line #{i} " + "x" * 30 }.join("\n"))
tool = Ask::Tools::Read.new
tool.byte_budget = 500
first = tool.call(path: "app.log")
resume = tool.call(path: "app.log", offset: first.metadata[:resume_offset], limit: 3)
resume.output
# => 13: line 13 xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
# 14: line 14 xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
# 15: line 15 xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
# ... (more lines) — resume with offset=15
```

A minified single-line bundle gets clamped, not returned whole:

```ruby
require "ask-tools-shell"

File.write("bundle.min.js", "a" * 5000 + "\n" + "normal line\n")
tool = Ask::Tools::Read.new
tool.max_line_chars = 100
clamped = tool.call(path: "bundle.min.js")
clamped.output
# => "1:
# aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
# aaaaaaaaaaaaaaaaaaaa…[clamped at 100 chars]\n" +
# "2: normal line"
```

Boring formats get one-line answers — facts, not errors:

```ruby
require "ask-tools-shell"

File.write("empty.txt", "")
File.binwrite("logo.png", "\x89PNG\r\n\x1a\n".b + "\x00".b * 64)

empty = Ask::Tools::Read.new.call(path: "empty.txt")
empty.output
# => "File is empty (0 lines)."

binary = Ask::Tools::Read.new.call(path: "logo.png")
binary.output
# => "Binary file (image/png, 72 bytes) — content not shown."
```

Unchanged re-reads return a self-expiring stub — the content is already in
the conversation, so paying for it again is pure waste:

```ruby
require "ask-tools-shell"

File.write("stable.txt", "alpha\nbeta\ngamma\n")
tool = Ask::Tools::Read.new

first = tool.call(path: "stable.txt")
second = tool.call(path: "stable.txt")
third = tool.call(path: "stable.txt")

first.output.lines.first.chomp
# => "1: alpha"

second.output
# => "File unchanged since last read — content is already in context."

third.output.lines.first.chomp
# => "1: alpha"
```

Device files are refused by name before any I/O:

```ruby
require "ask-tools-shell"

Ask::Tools::Read.new.call(path: "/dev/zero").error
# => "Refusing to read device file: /dev/zero (can block forever)."
```

When a path doesn't exist, the tool repairs it — first the invisible
character variants, then "did you mean?":

```ruby
require "ask-tools-shell"

File.write("AGENTS.md", "agent instructions")
suggestion = Ask::Tools::Read.new.call(path: "AGENT.md").error[/did you mean: ([^?]+)/, 1]
File.basename(suggestion)
# => "AGENTS.md"
```

The partial-view ledger protects the model from itself — `Write` refuses to
overwrite a file it only saw part of, until it re-reads the whole thing:

```ruby
require "ask-tools-shell"

File.write("plan.md", (1..30).map { |i| "line #{i}" }.join("\n"))

reader = Ask::Tools::Read.new
reader.max_lines = 10
reader.call(path: "plan.md")

denial = Ask::Tools::Write.new.call(path: "plan.md", content: "overwrite").error
File.basename(denial[/Refusing to overwrite ([^:]+)/, 1])
# => "plan.md"

denial[/only part of the file has been read[^.]+/]
# => "only part of the file has been read (lines 1–10 shown, more lines exist)"

# A full read clears the block — now the write goes through.
Ask::Tools::Read.new.call(path: "plan.md")
rewrite = Ask::Tools::Write.new.call(path: "plan.md", content: "rewritten")
rewrite.output[:bytes]
# => 9
```

### Repl — Persistent Ruby Sessions (v0.4.0+)

Where `Code` spawns a fresh `ruby -e` per call, `Repl` keeps a long-lived
plain-ruby kernel subprocess and evaluates every snippet into the same
binding. Locals, `require`s, and defined methods survive between calls — the
RLM (recursive language model) pattern: the model composes capabilities as
code against a working environment instead of re-bootstrapping it each time:

```ruby
require "ask-tools-shell"

# One long-lived session, many calls: the kernel remembers everything
# between them, like a real workspace.
repl = Ask::Tools::Repl.new
session = "docs-rlm"

File.write("scores.csv", "name,score\nada,97\nturing,88\nhopper,99\nlin,95")

# Build the working context once...
repl.call(code: 'require "csv"', session: session)
repl.call(code: 'rows = CSV.parse(File.read("scores.csv"), headers: true).map(&:to_h)', session: session)
repl.call(code: 'def average(rows, key) = rows.sum { |r| r[key].to_f } / rows.size', session: session)

# ...then keep working. Each call below is a single line of code —
# `rows`, `average`, and the csv require are all still there.
repl.call(code: 'rows.size', session: session).output[:result]                                        # => "4"
repl.call(code: 'average(rows, "score")', session: session).output[:result]                           # => "94.75"
repl.call(code: 'rows.count { |r| r["score"].to_f > average(rows, "score") }', session: session).output[:result] # => "3"
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

### Code vs Repl — which one to use

`Code` and `Repl` both run Ruby (and only Ruby), but they are built for
different jobs. Think of `Code` as a notepad you throw away after each note,
and `Repl` as a workspace you keep coming back to.

| | Code | Repl |
|---|---|---|
| Language | Ruby only | Ruby only |
| Lifetime | One call, then the process is gone | The session stays alive between calls |
| State | None — every call starts fresh | Variables, requires, and methods persist |
| Safety | Runs in the sandbox (Docker/Daytona/Cloudflare available) | Not sandboxed — run only code you trust |
| Result | stdout, stderr, exit code | The value of the last expression, plus stdout/stderr |

**Use `Code` when:**

- You need a single snippet and don't care what happens next.
- The code is untrusted — a user's input, something pasted from a webpage.
  The sandbox is the safety boundary.
- You want a guaranteed clean environment, with no state leaking in from an
  earlier run.

**Use `Repl` when:**

- You're doing a multi-step job: load data once, define helpers once, then
  keep working with them — no re-bootstrapping on every step.
- You want to see the value of the last expression, not just printed output.
- You're iterating on the same environment: tweak a function, test it,
  tweak again.

**Same task, both tools** — counting active users from a JSON file:

```ruby
# Code — one shot, state is gone afterwards
Ask::Tools::Code.new.call(
  code: 'require "json"; JSON.parse(File.read("users.json")).count { |u| u["active"] }'
)

# Repl — build it up, keep it around
repl = Ask::Tools::Repl.new
repl.call(code: 'require "json"', session: "users")
repl.call(code: 'users = JSON.parse(File.read("users.json"))', session: "users")
repl.call(code: 'users.count { |u| u["active"] }', session: "users")
```

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
