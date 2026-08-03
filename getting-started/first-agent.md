---
layout: default
title: Your First Agent
parent: Getting Started
nav_order: 1
---

# Your First Agent

> **The examples below were actually run.** Each `# =>` output is the real
> response the model gave when the example was executed against ask-agent
> and OpenCode Go — nothing is fabricated.

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

Create a file called `agent.rb`. It needs `OPENCODE_GO_API_KEY` set (step 2):

<!-- docs-example: recorded -->
```ruby
require "ask-agent"
require "ask-tools-shell"

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

<!-- docs-example: recorded -->
```ruby
require "ask-agent"
require "ask-tools-shell"
require "tmpdir"

# Run inside a temp dir so the demo file doesn't land in your project
response = Dir.mktmpdir do |dir|
  Dir.chdir(dir) do
    session = Ask::Agent::Session.new(
      model: "deepseek-v4-flash",
      provider: :opencode_go,
      tools: Ask::Tools::Shell::TOOLS  # 8 shell tools via the TOOLS constant
    )

    session.run("Create a file called hello.rb that prints a greeting, run it, and report the output.")
  end
end

response
# => Done! Here's what happened:
# 
# 1. **Created** `hello.rb` with the content:
#    ```ruby
#    puts "Hello, world!"
#    ```
# 
# 2. **Ran it** with `ruby <path-to-file>/hello.rb` (using the full path, since the bash session's working directory differs from where the file was written).
# 
# 3. **Output:**
#    ```
#    Hello, world!
#    ```
# 
# The script ran successfully and printed the greeting as expected.
```

The agent can now read, write, and edit files, glob, grep, run code, and apply patches. The example above shows a real run — your model may create the file differently.

## 5. Add streaming

<!-- docs-example: recorded -->
```ruby
require "ask-agent"
require "ask-tools-shell"

session = Ask::Agent::Session.new(
  model: "deepseek-v4-flash",
  provider: :opencode_go,
  tools: [Ask::Tools::Bash]
)

session.on_event do |event|
  case event
  when Ask::Agent::Events::TextDelta
    print event.content
  when Ask::Agent::Events::ToolExecutionStart
    puts "\n[Running #{event.name}...]"
  when Ask::Agent::Events::ToolExecutionEnd
    puts "\n[#{event.name} finished in #{event.duration_ms}ms]"
  end
end

response = session.run("Run `ruby -e 'p (1..10).map { |n| n * n }'` and answer with only the output.")
response
# => "[1, 4, 9, 16, 25, 36, 49, 64, 81, 100]"
```

You'll see the agent's response stream in real-time, with tool execution progress indicators. The example above shows a real run — run it yourself to see it live.

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
