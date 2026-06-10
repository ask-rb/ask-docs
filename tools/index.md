---
layout: default
title: ask-tools
nav_order: 4
---

# ask-tools

**The foundational tool framework for the ask-rb ecosystem.** Defines `Ask::Tool` (base class), `Ask::Result` (standardized return value), and tool discovery/registration. Zero external dependencies.

```ruby
gem "ask-tools"
```

This gem does **not** ship executable tools. It only provides the contract that tool gems (e.g., `ask-tools-shell`) implement.

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
| `param(name, type:, desc:, required:)` | Declares a parameter. `type` must be a valid JSON Schema type |

### Instance Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `name` | `String` | Auto-derived from class name: CamelCase → snake_case, strips `_tool` |
| `description` | `String?` | The tool's description |
| `parameters` | `Hash{Symbol => Parameter}` | Declared parameter definitions |
| `call(args = {})` | `Ask::Result` | Normalizes args, validates, delegates to `execute` |
| `execute(**args)` | `Ask::Result` | **Override this.** Implement the tool's logic |
| `params_schema` | `Hash?` | JSON Schema hash for LLM function-calling APIs |
| `tool_definition` | `Hash` | Full tool definition with name, description, input_schema |

### Error Handling

- **`Ask::Tool::Halt`** — Raise inside `execute` to stop the conversation loop.
- **`StandardError`** — Caught by `call` and returned as error `Ask::Result`.

---

## `Ask::Result` — Standardized Return Value

```ruby
# Factories
Ask::Result.ok(data: "output")
Ask::Result.error(message: "fail")

# Attributes
result.ok?         # => true / false
result.output      # => "output"
result.error       # => nil / "fail"
result.metadata    # => {}
result.to_s        # => human-readable
result.to_h        # => { ok: true, output: "...", error: nil, metadata: {} }
```

---

## `Ask::Tools` — Registry & Discovery

```ruby
Ask::Tools.register(MyTool)
Ask::Tools.all          # => [MyTool.new, ...]
Ask::Tools.discover     # auto-discover loaded Ask::Tool subclasses
Ask::Tools["my_tool"]   # find by derived name
Ask::Tools.count        # => 1
Ask::Tools.clear        # reset
```

Thread-safe via `Monitor`.

---

## Writing Custom Tools

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

**Shell, filesystem, and code execution tools.** Ships 7 tools every agent needs: Bash, Read, Write, Edit, Glob, Grep, and Code.

```ruby
gem "ask-tools-shell"
```

### Quick Start

```ruby
require "ask-tools-shell"

Ask::Tools::Shell.all.map(&:name)
# => ["bash", "read", "write", "edit", "glob", "grep", "code"]

Ask::Tools::Bash.new.call(command: "echo hello")
Ask::Tools::Read.new.call(path: "/etc/hosts")
Ask::Tools::Code.new.call(code: "puts RUBY_VERSION")
```

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

### Links

- **Source:** [github.com/ask-rb/ask-tools-shell](https://github.com/ask-rb/ask-tools-shell)
- **Rubygems:** [rubygems.org/gems/ask-tools-shell](https://rubygems.org/gems/ask-tools-shell)
