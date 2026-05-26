---
layout: default
title: ask-core
nav_order: 2
---

# ask-core

**The foundation gem.** Zero dependencies. Every `ask-rb` app depends on this.

```ruby
gem "ask-core"
```

## What it provides

### Conversation

The core data structure — an ordered list of messages that can be serialized for any provider API.

```ruby
conversation = Ask::Conversation.new
conversation.add_message(:system, "You are a helpful assistant")
conversation.add_message(:user, "What's the weather in Paris?")
conversation.add_message(:assistant, tool_calls: [
  { id: "call_1", name: "get_weather", arguments: { city: "Paris" } }
])
conversation.to_a  # => array of hashes ready for API call
```

### Streaming

Receive responses incrementally without mutating state.

```ruby
stream = Ask::Stream.new
stream.each { |chunk| print chunk.content }
stream.transcript  # full accumulated response
```

### Provider interface

A base class that all provider gems implement.

```ruby
class MyProvider < Ask::Provider
  def chat(conversation, tools: [], model: nil, &stream_block)
    # Returns Ask::Response or calls stream_block with Ask::Chunk
  end
end
```

### Auth helpers

```ruby
Ask::Auth.from_env("OPENAI_API_KEY")          # env var
Ask::Auth::OAuth.new(client_id: "...")         # PKCE flow
Ask::Auth::CredentialStore.new(path: "...")    # file-backed with 0600
```

### Role mapping

```ruby
Ask::RoleMap.normalize("developer")  # => "system"
Ask::RoleMap.normalize("ai")         # => "assistant"
```

## Exports

`Conversation`, `Stream`, `Chunk`, `Response`, `Provider`, `ToolDef`, `ToolCall`, `Auth`, `Auth::OAuth`,
`Auth::CredentialStore`, `RoleMap`, `Error` classes.
