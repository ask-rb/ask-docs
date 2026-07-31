---
layout: default
title: Actions
parent: Rails Integration
nav_order: 3
---

# Actions

Actions are the operations your users trigger — booking an appointment, creating a chat, upgrading a plan. They live in `app/actions/` and are dispatched **by name**, so every channel (web controller, Slack handler, voice agent) invokes the same operation through the same contract.

This is the pattern for making your business logic callable from any surface — one action, many interfaces.

## What ask-rails provides

| Piece | Purpose |
|---|---|
| `Ask::Actions::Result` | The uniform response shape every action returns |
| `Ask::Actions::Context` | A per-request context bag — channel adapters build it, actions read it |
| `Ask::Actions::Backend` | Dispatches named actions to their classes |
| `ApplicationAction` | Base class for your actions (`call(context:, params:)` → `#call`) |
| `ask:action` generator | Scaffolds actions under `app/actions/` |

## Installation

`ask:install` already creates `app/actions/` and `app/actions/application_action.rb`:

```bash
rails generate ask:install
```

## Writing an action

Actions respond to `call(context:, params:)` and return an `Ask::Actions::Result`:

```ruby
# app/actions/chats/create.rb
module Chats
  class Create < ApplicationAction
    def call
      chat = context.channel.start_new_chat!
      Ask::Actions::Result.ok(message: "Chat created", data: { chat: chat })
    end
  end
end
```

The base class wires `call(context:, params:)` to your `#call` instance method and exposes `context` and `params` as readers.

### Result

`Ask::Actions::Result` is the contract every caller can rely on:

| Method | Purpose |
|---|---|
| `.ok(message:, data: {}, code: nil)` | Success response |
| `.error(message:, data: {}, code: nil)` | Failure response |
| `ok?` / `error?` | Check outcome |
| `message` | Human-readable summary |
| `data` | Structured payload (a hash) |
| `code` | Machine-readable status (e.g. `:slot_taken`) |
| `to_h` | Hash serialization for logging or agent-facing output |

Extra channel-specific fields (like a web redirect) belong in `data` or in a subclass — the generic contract stays clean.

### Context

Channel adapters construct the context with whatever the app needs; attributes become accessors:

```ruby
context = Ask::Actions::Context.new(
  user: current_user,
  session: session,
  workspace: current_workspace,
  voice_call: call
)

context.workspace # => the workspace
```

Actions only read from the context — they never build it.

## Dispatching

Dispatch by name from any channel:

```ruby
result = Ask::Actions.dispatch(
  action: "chats.create",
  context: context,
  params: { name: "general" }
)

result.ok?     # => true
result.message # => "Chat created"
result.data    # => { chat: ... }
```

### Name resolution

`"chats.create"` resolves to `Chats::Create` by convention — no registration needed. Zeitwerk autoloads `app/actions/` automatically:

| Dispatch name | File | Class |
|---|---|---|
| `"chats.create"` | `app/actions/chats/create.rb` | `Chats::Create` |
| `"api_tokens.create"` | `app/actions/api_tokens/create.rb` | `ApiTokens::Create` |
| `"create_workspace"` | `app/actions/create_workspace.rb` | `CreateWorkspace` |

Action names are lowercase, snake_case parts joined by dots (`[a-z0-9_.]+`). Anything else raises `Ask::Actions::Backend::UnknownAction` with guidance — the dispatcher never constantizes untrusted strings.

### Registration

Register explicitly to override the convention or to list the action in `Ask::Actions.available`:

```ruby
# config/initializers/ask.rb
Ask::Actions.register "chats.create", Chats::Create
```

```ruby
Ask::Actions.available # => ["chats.create"]
```

Registration always takes precedence over convention resolution.

## The generator

```bash
rails generate ask:action create_workspace   # app/actions/create_workspace.rb
rails generate ask:action chats create       # app/actions/chats/create.rb
```

## Where actions fit

- **Actions** are atomic operations — one call, one `Result`. Use them for everything short and deterministic.
- **Ask-graph workflows** orchestrate actions over time — reminders, follow-ups, multi-step processes with checkpoints and approval.
- **Agents** decide which actions to run from a conversation — the `Ask::Agent` loop calls tools that dispatch actions.

A voice agent that books appointments, a web button, and a Slack command can all call `"appointments.create"` — the logic is written once and shared by every surface.
