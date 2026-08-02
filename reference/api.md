---
layout: default
title: API Reference
parent: Reference
nav_order: 2
---

# API Reference

Key classes and methods across the ask-rb ecosystem. For full documentation, see each gem's README and YARD docs.

## ask-core

The foundation gem. [Source](https://github.com/ask-rb/ask-core)

`gem "ask-core"` — zero dependencies, every ask-rb app depends on it.

### Ask::Provider

```ruby
class MyProvider < Ask::Provider
  def api_base = "https://api.example.com/v1"
  def headers = { "Authorization" => "Bearer #{@config.api_key}" }
  def chat(messages, model:, tools: nil, temperature: nil, stream: nil, schema: nil, **params, &block)
  def embed(text, model:)
  def list_models
end

Ask::Provider.register(:name, MyProvider)
Ask::Provider.resolve(:name)
Ask::Provider.providers  # => Hash of registered providers
```

### Ask::Conversation

```ruby
conv = Ask::Conversation.new
conv.system("text")
conv.user("text")
conv.assistant("text", tool_calls: [...])
conv.tool_result("text", tool_call_id: "id")
conv.messages   # => Array of Ask::Message
conv.user_messages
conv.assistant_messages
conv.tool_messages
conv.system_messages
conv.to_a       # => Array of hashes
```

### Ask::Message

```ruby
msg = Ask::Message.new(role: :user, content: "Hello")
msg.role         # => :user
msg.content      # => "Hello"
msg.tool_calls   # => Array or nil
msg.tool_call_id # => String or nil
msg.user?        # Boolean
msg.assistant?   # Boolean
msg.tool_call?   # Boolean
msg.tool_result? # Boolean
```

### Ask::Stream / Ask::Chunk

```ruby
stream = Ask::Stream.new { |chunk| print chunk.content }
stream.add(Ask::Chunk.new(content: "Hello"))
stream.finish!
stream.accumulated_text  # => "Hello"
stream.to_s              # => "Hello"
stream.accumulated_usage # => { input_tokens: 10, output_tokens: 20 }
stream.length            # => 2
```

### Ask::ModelCatalog

```ruby
catalog = Ask::ModelCatalog.new([Ask::ModelInfo.new(id: "gpt-4o", provider: "openai")])
catalog.find("gpt-4o")
catalog.chat_models
catalog.embedding_models
catalog.by_provider("openai")

# Singleton
Ask::ModelCatalog.instance
Ask::ModelCatalog.find("gpt-4o")
```

### Ask::ToolDef

```ruby
tool = Ask::ToolDef.new(
  name: "get_weather",
  description: "Get current weather",
  parameters: { type: "object", properties: { location: { type: "string" } }, required: ["location"] }
)
tool.frozen?      # => true
tool.to_provider_format { |t| { type: "function", function: t.to_h } }
```

### Ask::Result

```ruby
Ask::Result.success("Data processed")
Ask::Result.failure("API returned 500")
Ask::Result.aborted("Cancelled")
Ask::Result.blocked("Permission denied")

result.success?  # => true/false
result.error?    # => true/false
result.to_h      # => { content: "...", status: :success, metadata: {} }
```

### Errors

```ruby
Ask::ConfigurationError
Ask::UnknownProvider
Ask::ModelNotFound
Ask::InvalidRole
Ask::InvalidToolDefinition
Ask::ProviderError
Ask::ContextLengthExceeded
Ask::RateLimitError
Ask::Unauthorized
Ask::ServerError
Ask::ServiceUnavailable
Ask::ConversationError
Ask::StreamError
Ask::UnsupportedFeature
Ask::MissingCredential
Ask::InvalidCredential
```

## ask-auth

Credential resolution. [Source](https://github.com/ask-rb/ask-auth)

`gem "ask-auth"` — pulled in by every service gem and by ask-llm-providers.

```ruby
Ask::Auth.resolve(:github_token)
Ask::Auth.resolve(:github_token, user: current_user)

Ask::Auth.configure do |c|
  c.providers = [Ask::Auth::Providers::Env.new, Ask::Auth::Providers::File.new]
end
```

## ask-tools

Tool framework. [Source](https://github.com/ask-rb/ask-tools)

`gem "ask-tools"` — no executable tools inside; add `ask-tools-shell` for shell and filesystem tools.

```ruby
class MyTool < Ask::Tool
  description "Does something"
  param :input, type: :string, desc: "Input value", required: true
  def execute(input:)
    Ask::Result.ok(data: "Processed #{input}")
  end
end

Ask::Tools.register(MyTool)
Ask::Tools.all
Ask::Tools["my_tool"]
Ask::Tools.count
```

## ask-agent

Agent loop. [Source](https://github.com/ask-rb/ask-agent)

`gem "ask-agent"` — pulls in ask-core, ask-llm-providers, ask-tools, ask-skills, ask-state-providers, and ask-instrumentation.

### Agent Definitions

```ruby
# agents/health_check/agent.rb
module HealthCheck
  class Agent < Ask::Agent::Definition
    model "gpt-4o"
    tools :bash, :read, :grep
    schedule "every 5 minutes"
  end
end

# Usage
agent = Ask::Agent.new("health_check")
agent.run("Check health")

Ask::Agent.definitions  # => { "health_check" => [HealthCheck::Agent, "/path/to/agents/health_check"] }
Ask::Agent.rediscover!
```

### Low-Level Session API

```ruby
session.on_event { |event| ... }
session.id
session.total_cost
session.turn_count
session.total_input_tokens
session.total_output_tokens

Ask::Agent.configure do |c|
  c.default_model = "claude-sonnet-4"
  c.default_max_turns = 50
  c.parallel_tool_execution = true
end
```

### Middleware (LLM Call Pipeline)

```ruby
Ask::Agent.configure do |c|
  c.middleware.use :retry_on_failure, max_retries: 5
  c.middleware.use :log_calls, logger: Rails.logger
  c.middleware.use :default_settings, temperature: 0.7
end

# Custom middleware
class MyMiddleware < Ask::Agent::Middleware::Base
  def around_request(provider, request)
    # request is a Hash with :messages, :model, :tools, :temperature, :stream, :schema, :extra_params
    Rails.logger.info "Calling #{request[:model]}"
    result = yield
    Rails.logger.info "Done"
    result
  end
end
```

### Stream Transforms

```ruby
Ask::Agent.configure do |c|
  c.stream_transforms.use :thinking_separator
  c.stream_transforms.use :text_buffer, min_size: 100
  c.stream_transforms.use :extract_json
end

# Custom transform
class NoOp < Ask::Agent::StreamTransforms::Base
  def call(chunk, &block)
    yield chunk
  end
	end
	```

### Ask.chat (convenience)

```ruby
# Quick one-shot chat — no Session setup needed
Ask.chat("Hello!")
Ask.chat("Tell me about X", model: "gpt-4o")

# With streaming
Ask.chat("Stream this") { |chunk| puts chunk.content if chunk.content }
```

### Prompt Caching

```ruby
# Enabled by default. Disable if needed.
Ask::Agent.configure do |c|
  c.prompt_caching = false
end

# Per-session override
session = Ask::Agent::Session.new(model: "claude-sonnet-4", prompt_caching: false)

# Cache token metadata (available in response metadata)
#   Anthropic: :cache_creation_input_tokens, :cache_read_input_tokens
#   OpenAI:    :cached_tokens
```

### Scheduler

```ruby
Ask::Agent.configure do |c|
  c.scheduler.every "5 minutes", name: "task-name" do
    Ask::Agent::Session.new(model: "gpt-4o").run("Do something")
  end
  c.scheduler.cron "0 9 * * 1-5", name: "weekday-task"
end

Ask::Agent::Scheduler.start
Ask::Agent::Scheduler.running?
Ask::Agent::Scheduler.jobs
Ask::Agent::Scheduler.job_by_name("task-name")
Ask::Agent::Scheduler.stop
```

## ask-rails

Rails integration for building AI-powered applications. [Source](https://github.com/ask-rb/ask-rails)

`gem "ask-rails"` — requires Rails 7.1+ and ask-agent.

**Use ask-rails for:** Adding AI capabilities to your Rails app for your users.

```ruby
# Terminal
rails generate ask:install

# config/initializers/ask.rb
Ask::Agent.configure do |config|
  config.default_model = ENV.fetch("ASK_DEFAULT_MODEL", "gpt-4o")
end
```

```ruby
# app/agents/support_bot/agent.rb
module SupportBot
  class Agent < ApplicationAgent
    model "gpt-4o"
    tools :search_products
  end
end

# Anywhere in your app
agent = Ask::Agent.new("support_bot")
agent.run("How do I reset my password?")

  # One-off conversations
  session = Ask::Agent::Session.new(model: "gpt-4o")
  session.run("Summarize this article") do |chunk|
  puts chunk.content if chunk.content
  end
  ```

  **Dependencies:** `ask-agent` (pulls in `ask-core`, `ask-llm-providers`, `ask-tools`, `ask-skills`).

  ## ask-rails-harness

  Admin AI copilot for Rails apps. [Source](https://github.com/ask-rb/ask-rails-harness)

  `gem "ask-rails-harness"` — requires Rails 7.1+; pulls in ask-agent, ask-tools, ask-tools-shell, and ask-auth.

  **Use ask-rails-harness for:** Internal admin agents that inspect code, query DB, read logs.

  ```ruby
  # Gemfile
  gem "ask-rails-harness"

  # Terminal
  rails generate ask_rails_harness:install
  ```

  ```ruby
  # config/routes.rb
  authenticate :user, ->(u) { u.admin? } do
  mount Ask::Rails::Harness::Engine, at: "/ask"
  end
  ```

  ```ruby
  # Programmatic access
  Ask::Rails::Harness.agent_session
  Ask::Rails::Harness.agent_session(user: current_user)

  Ask::Rails::Harness.configure do |c|
  c.default_model = "gpt-4o"
  c.max_turns = 50
  end

  # Auth
  Ask::Rails::Harness::Auth.check = -> {
  redirect_to main_app.login_path unless current_user&.admin?
  }

  # Engine routes (mounted at /ask)
  # GET  /ask                    → Admin chat UI
  # POST /ask/sessions           → Create session
  # POST /ask/sessions/:id/messages → Send message (SSE streamed)
  # GET  /ask/sessions/:id/messages → Message history
  ```

  **Dependencies:** `ask-agent`, `ask-tools-shell`, `ask-auth`, `rails >= 7.1`.

## ask-tools-shell

Shell and filesystem tools. [Source](https://github.com/ask-rb/ask-tools-shell)

`gem "ask-tools-shell"` — depends on ask-tools and ask-sandbox-providers.

  ```ruby
  Ask::Tools::Bash.new.call(command: "ls")
  Ask::Tools::Read.new.call(path: "/etc/hosts")
  Ask::Tools::Write.new.call(path: "file.txt", content: "data")
  Ask::Tools::Edit.new.call(path: "file.txt", old_string: "old", new_string: "new")
  Ask::Tools::Glob.new.call(pattern: "**/*.rb")
  Ask::Tools::Grep.new.call(pattern: "class")
  Ask::Tools::Code.new.call(code: "puts RUBY_VERSION")
  Ask::Tools::ApplyPatch.new.call(patchText: "--- a/file\n+++ b/file\n@@ ...")
  ```

  ## ask-llm-providers

  LLM providers. [Source](https://github.com/ask-rb/ask-llm-providers)

  `gem "ask-llm-providers"` — all 33 providers in one gem; also loads the model catalog into `Ask::ModelCatalog`.

  ```ruby
  Ask::Providers::OpenAI.new(api_key: "sk-...")
  Ask::Providers::Anthropic.new(api_key: "sk-ant-...")
  Ask::Providers::Google.new(api_key: "...")
  Ask::Providers::Bedrock.new(...)
  Ask::Providers::Ollama.new(...)
  Ask::Providers::Mistral.new(api_key: "...")
  Ask::Providers::Cloudflare.new(api_key: "...", account_id: "...")

  Ask::Providers::OpenAI.capabilities
  Ask::Providers::Ollama.local?
  ```

  ## ask-skills

  Skill discovery and management. [Source](https://github.com/ask-rb/ask-skills)

  `gem "ask-skills"` — a dependency of ask-agent, so agent users get it automatically.

  ```ruby
  # Discover skills from all configured sources
  registry = Ask::Skills.discover
  registry.names              # => ["rails_debug", "deploy_bot", ...]
  registry["rails_debug"]     # => Skill object

  # Discover with per-agent skills (highest priority)
  registry = Ask::Skills.discover(agent_dir: "agents/health_check")

  # Load an arbitrary markdown file as a skill
  skill = Ask::Skills.load_file("path/to/skill.md")

  	# Skill data object
  	skill.name         # => "rails_debug"
  	skill.description  # => "Debugging Rails apps"
  	skill.instructions # => full markdown body
  	skill.source       # => "/path/to/SKILL.md"
  	skill.tags         # => ["rails", "database", "debugging"]
  	skill.references   # => ["references/migration_guide.md"]
  	skill.scripts      # => ["scripts/db_check.sh"]
  	skill.assets       # => ["assets/diagram.png"]
  	skill.siblings     # => {"references" => [...], "scripts" => [...]}
  	```

  	### Enhanced Frontmatter

  	```markdown
  	---
  	name: rails_debug
  	description: Debug Rails database issues
  	tags: rails, database, debugging
  	version: 2
  	author: Myrr Labs
  	---
  	```

  	### Sibling Files

  	Skills can bundle reference documents, scripts, and assets alongside `SKILL.md`:

  	```
  	rails_debug/
  	├── SKILL.md
  	├── references/       → skill.references
  	│   ├── migration_guide.md
  	│   └── apis.md
  	├── scripts/          → skill.scripts
  	│   └── db_check.sh
  	└── assets/           → skill.assets
  	    └── diagram.png
  	```

  	### CLI

  	```bash
  	askr skills list              # All skills with descriptions and tags
  	askr skills show rails_debug  # Full details + instructions + siblings
  	askr skills search deploy     # Search by name, description, or tags
  	```

  Discovery sources (highest priority first):
  1. Per-agent: `agents/<name>/skills/` (when `agent_dir` given)
  2. Shared project: `agents/shared/skills/`, `app/agents/shared/skills/`
  3. User config: `~/.config/ask/skills/`
  4. Installed gems
  5. Built-in skills (`skill.design`, `skill.compose`)

  ## ask-sandbox-providers

  Sandboxed execution. [Source](https://github.com/ask-rb/ask-sandbox-providers)

  `gem "ask-sandbox-providers"` — used by the Bash and Code tools in ask-tools-shell.

  ```ruby
  Ask::Sandbox.provider = :docker
  Ask::Sandbox.provider = Ask::Sandbox::Docker.new(image: "ruby:3.4-alpine")
  Ask::Sandbox.provider = Ask::Sandbox::Daytona.new(api_key: "...")
  Ask::Sandbox.provider = Ask::Sandbox::Cloudflare.new(worker_url: "...")

  result = Ask::Sandbox.provider.call(["ruby", "-e", "puts 1+1"])
  result.stdout     # => "2\n"
  result.exit_code  # => 0
  result.success?   # => true
  ```

  ## ask-state-providers

  Pluggable state backends for key-value storage, session persistence, distributed locking, message queues, and ordered lists. [Source](https://github.com/ask-rb/ask-state-providers)

  `gem "ask-state-providers"` — a dependency of ask-agent and ask-graph for session persistence and workflow checkpoints.

  ```ruby
  # In-memory (default, lives in ask-state-providers since v0.3.0)
  store = Ask::State::Memory.new

  # Key-value with TTL
  store.set("key", "value", ttl: 60)
  store.get("key")         # => "value"
  store.delete("key")

  store.set_if_not_exists("lock", "acquired")  # atomic create

  # Distributed locking
  lock = store.acquire_lock("resource", ttl: 10)
  store.release_lock("resource", lock) if lock

  # Message queues
  store.enqueue("queue-name", { task: "work" })
  entry = store.dequeue("queue-name")
  entry.value       # => { task: "work" }
  entry.id          # => UUID
  entry.enqueued_at # => Time

  # Ordered lists with optional max length
  store.list_append("sessions", "session-1", max_length: 100)
  store.list_range("sessions", 0, -1)
  store.list_remove("sessions", "session-1")

  # Persistent backends
  Ask::State::Providers::SQLite.new              # file-backed (default: sessions.db)
  Ask::State::Providers::SQLite.new(path: "state.sqlite")
  Ask::State::Providers::Redis.new(url: ENV["REDIS_URL"])
  Ask::State::Providers::Postgres.new(url: ENV["DATABASE_URL"])
  Ask::State::Providers::MySQL.new(url: ENV["MYSQL_URL"])
  ```

  Data types: `Ask::State::Lock` (`.id`, `.token`, `.expires_at`, `.expired?`), `Ask::State::QueueEntry` (`.id`, `.value`, `.enqueued_at`).

  ## ask-provider-tool (in ask-core)

  Configuration for built-in tools that run on the provider's infrastructure. Part of `ask-core`.

  ```ruby
  # Provider-executed tools (handled by OpenAI's servers)
  Ask::ProviderTool.web_search(search_context_size: "high")
  Ask::ProviderTool.file_search(vector_store_ids: ["vs_abc"], max_num_results: 10)
  Ask::ProviderTool.code_interpreter(file_ids: ["file_1"])

  # Custom provider tool
  Ask::ProviderTool.new(
  id: "openai.web_search",
  name: "web_search",
  args: { search_context_size: "medium" }
  )

  # Use with sessions
  session = Ask::Agent::Session.new(
  model: "gpt-4o",
  tools: [Bash, Read, Ask::ProviderTool.web_search]
  )
  ```

  ## ask-schema

  JSON Schema DSL. [Source](https://github.com/ask-rb/ask-schema)

  `gem "ask-schema"` — a dependency of ask-tools, which uses it for tool parameter schemas.

  ```ruby
  schema = Ask::Schema.create do
    string :name
    integer :count
    array :tags, of: :string
    object :meta do
      string :version
    end
  end

  schema.new("example").to_json_schema
  ```

## ask-mcp

MCP client and server. [Source](https://github.com/ask-rb/ask-mcp)

`gem "ask-mcp"` — needed by ask-web-search-mcp and ask-rails-harness-mcp, which both build on it.

```ruby
client = Ask::MCP.from_stdio("npx", ["-y", "server-package"])
client.start
client.tools       # => Hash of name → Ask::MCP::Tool
client.call_tool("tool_name", arg1: "value")
client.stop
```

## ask-eval

LLM evaluation. [Source](https://github.com/ask-rb/ask-eval)

`gem "ask-eval"` — Minitest plugin auto-loads with `require "ask/eval/minitest"`.

```ruby
assert_faithful response, context: docs
assert_not_hallucinating response, context: docs
refute_bias response
refute_toxicity response
assert_correctness response, expected: expected
assert_contains response, "substring"
assert_regex response, /pattern/
```

## Next Steps

- [Browse the Gem Index](/ask-docs/reference/gems)
- [Read the Design Philosophy](/ask-docs/reference/design)
- [Get started with your first agent](/ask-docs/getting-started/first-agent)
