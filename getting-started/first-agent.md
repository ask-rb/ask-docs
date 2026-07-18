---
layout: default
title: Your First Agent
parent: Getting Started
nav_order: 1
---

# Your First Agent

Build a working AI agent in under 5 minutes. You'll need Ruby 3.2+ and an API key from OpenAI or Anthropic.

## 1. Install

```bash
gem install ask-agent
```

This installs the agent runtime plus the shell tools (bash, read, write, glob, grep) and the LLM provider gem.

## 2. Set your API key

```bash
export OPENAI_API_KEY="sk-your-key-here"
```

Or for Anthropic:

```bash
export ANTHROPIC_API_KEY="sk-ant-your-key-here"
```

## 3. Create an agent

Create a file called `agent.rb`:

```ruby
require "ask-agent"

session = Ask::Agent::Session.new(
  model: "gpt-4o",
  tools: [Ask::Tools::Shell::Bash, Ask::Tools::Shell::Read, Ask::Tools::Shell::Write]
)

response = session.run("What Ruby version is installed?")
puts response
```

Run it:

```bash
ruby agent.rb
```

You should see the agent running a bash command to check the Ruby version and reporting back.

### Using a different provider

Some models are registered under one provider but served by another. For example, `deepseek-v4-flash` is in the model catalog under the `deepseek` provider, but you might access it through `opencode_go`. Pass the `provider:` parameter to override:

```ruby
session = Ask::Agent::Session.new(
  model: "deepseek-v4-flash",
  provider: :opencode_go,
  tools: [Ask::Tools::Shell::Bash, Ask::Tools::Shell::Read, Ask::Tools::Shell::Write]
)
```

This works with any OpenAI-compatible provider — set `OPENCODE_API_KEY` (or `OPENCODE_GO_API_KEY`) in your environment and the agent resolves everything automatically.

## 4. Give it more tools

```ruby
session = Ask::Agent::Session.new(
  model: "gpt-4o",
  tools: Ask::Tools::Shell::TOOLS  # 7 shell tools via the TOOLS constant
)

response = session.run("Create a file called hello.rb that prints a greeting")
```

The agent can now read, write, edit files, glob, grep, and run code.

## 5. Add streaming

```ruby
session = Ask::Agent::Session.new(
  model: "gpt-4o",
  tools: [Ask::Tools::Shell::Bash]
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
- The **provider** (OpenAI, Anthropic, etc.) handles model communication

## Next steps

- [Add AI to your Rails app](/getting-started/rails-ai)
- [Learn the core concepts](/getting-started/concepts)
- [Explore all tools](/core/tools)
- [Build custom tools](/extending/custom-tools)
