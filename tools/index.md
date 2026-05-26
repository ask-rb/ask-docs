---
layout: default
title: ask-tools
nav_order: 4
---

# ask-tools

**Built-in tool implementations.** No agent concepts — just tools you can use anywhere.

```ruby
gem "ask-tools"
```

## Usage

```ruby
# List all available tools
Ask::Tools.all  # => [Bash, Read, Write, Edit, Glob, Grep]

# Use without any LLM
Ask::Tools::Bash.new.call(cmd: "ls -la")
Ask::Tools::Read.new.call(path: "/etc/hosts")
Ask::Tools::Grep.new.call(pattern: "TODO", path: ".")

# Pass to a provider as tool definitions
provider.chat(conversation, tools: Ask::Tools.all)
```

## Writing custom tools

```ruby
class MyTool < Ask::Tool
  def name; "my_tool"; end
  def description; "Does something useful"; end
  def parameters
    { type: "object", properties: { input: { type: "string" } } }
  end
  def call(input:, **)
    Ask::Result.new(output: process(input))
  end
end
```
