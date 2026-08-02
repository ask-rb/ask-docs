---
layout: default
title: Your First Agent
parent: Getting Started
nav_order: 1
---

# Your First Agent

You'll need Ruby 3.2+ and an API key for whichever model you want to use. ask-rb talks to 33 providers: OpenAI, Anthropic, Google Gemini, Mistral, Amazon Bedrock, Cloudflare, plus 26 OpenAI-compatible APIs (DeepSeek, Groq, OpenRouter, xAI, Perplexity, and more). No key needed if you run Ollama locally. Pick what fits your project.

## 1. Install

```bash
gem install ask-agent ask-tools-shell
```

`ask-agent` is the runtime. `ask-tools-shell` adds the shell tools (bash, read, write, glob, grep) that the examples below use.

## 2. Set your API key

Keys are read from environment variables at runtime. This guide's examples use OpenCode Go, an OpenAI-compatible gateway:

```bash
export OPENCODE_GO_API_KEY="your-key-here"
```

Or any other provider:

```bash
export OPENAI_API_KEY="sk-your-key-here"
export GEMINI_API_KEY="your-key-here"
export MISTRAL_API_KEY="your-key-here"
export DEEPSEEK_API_KEY="your-key-here"
```

With Ollama there's nothing to set — it runs locally on `localhost:11434` and needs no key.

## 3. Create an agent

Create a file called `agent.rb`:

```ruby
require "ask-agent"
require "ask-tools-shell"

# recorded
# Live agent run, taped with ask-eval's Recorder. Requires OPENCODE_GO_API_KEY.
session = Ask::Agent::Session.new(
  model: "deepseek-v4-flash",
  provider: :opencode_go,
  tools: [Ask::Tools::Bash, Ask::Tools::Read, Ask::Tools::Write]
)

response = session.run("Run `ruby -v` and answer with only the version string.")
response
# => "ruby 4.0.1"
```

Run it:

```bash
ruby agent.rb
```

The agent runs a bash command to check the Ruby version and reports back. The example above shows a real response; your model may phrase it differently.

### Using a different provider

The provider is resolved from the model name. `"gpt-4o"` picks OpenAI, `"claude-sonnet-4"` picks Anthropic, `"gemini-2.0-flash"` picks Google, and so on.

Sometimes you want a model that's registered under one provider but served by another. The example above does exactly this: `deepseek-v4-flash` is cataloged under the `deepseek` provider, but we reach it through `opencode_go`, an OpenAI-compatible gateway, by passing `provider:`:

```ruby
session = Ask::Agent::Session.new(
  model: "deepseek-v4-flash",
  provider: :opencode_go,
  tools: [Ask::Tools::Bash, Ask::Tools::Read, Ask::Tools::Write]
)
```

Set the matching `*_API_KEY` env var (`OPENCODE_GO_API_KEY` here) and the agent resolves everything automatically. The same works for any OpenAI-compatible provider in the registry — pass its slug as `provider:`.

## 4. Give it more tools

```ruby
# not-verified: runs a live agent session; output varies per run
session = Ask::Agent::Session.new(
  model: "gpt-4o",
  tools: Ask::Tools::Shell::TOOLS  # 8 shell tools via the TOOLS constant
)

response = session.run("Create a file called hello.rb that prints a greeting")
```

The agent can now read, write, and edit files, glob, grep, run code, and apply patches.

## 5. Add streaming

```ruby
# not-verified: streams a live agent session
session = Ask::Agent::Session.new(
  model: "gpt-4o",
  tools: [Ask::Tools::Bash]
)

session.on_event do |event|
  case event
  when Ask::Agent::Events::TextDelta
    print event.content
  when Ask::Agent::Events::ToolExecutionStart
    puts "\n[Running #{event.name}...]"
  when Ask::Agent::Events::ToolExecutionComplete
    puts "\n[#{event.name} finished in #{event.duration_ms}ms]"
  end
end

response = session.run("What's the current date and who's the user?")
```

You'll see the agent's response stream in real-time, with tool execution progress indicators.

## What just happened?

- **Ask::Agent::Session** manages the think-call-execute loop
- **Tools** give the agent capabilities (bash, filesystem access)
- **Events** let you observe the agent in real-time
- The **provider** (OpenAI, Anthropic, or any of 30+) handles model communication

## Next steps

- [Add AI to Your Rails App](/ask-docs/getting-started/rails-app) — build user-facing AI features in your Rails app using ask-rails
- [Give Agents Access to Your Rails App](/ask-docs/getting-started/rails-ai) — set up the admin copilot for internal debugging and ops
- [Learn the core concepts](/ask-docs/getting-started/concepts)
- [Explore all tools](/ask-docs/core/tools)
- [Build custom tools](/ask-docs/extending/custom-tools)
