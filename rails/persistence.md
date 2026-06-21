---
layout: default
title: Persistence
parent: Rails Integration
nav_order: 3
---

# Persistence

Save, load, and resume agent sessions using ActiveRecord. By default, sessions run in-memory with no database needed. Add persistence when you need to continue conversations across requests.

## How It Works

When you create a session with a user context, the session is automatically persisted:

```ruby
# In-memory (default) — no database needed
session = Ask::Rails.agent_session

# Persisted — requires the migration
session = Ask::Rails.agent_session(user: current_user)
session.run("What models do we have?")
# Session is saved to the database
```

## Session Lifecycle

```ruby
# Create — session is saved after first message
session = Ask::Rails.agent_session(user: current_user)
session.run("Hello")

# Resume — load by session ID
saved_id = session.id
later = Ask::Rails.resume(saved_id)
later.run("Tell me more")

# The resumed session remembers the full conversation history
```

## Database Schema

The migration creates a single table:

```ruby
create_table :ask_sessions do |t|
  t.references :user, null: false, polymorphic: true
  t.text :conversation_data  # Serialized conversation
  t.string :model
  t.integer :turns, default: 0
  t.datetime :last_used_at
  t.timestamps
end
```

## Configuration

```ruby
Ask::Rails.configure do |c|
  # Auto-save every N turns
  c.persistence_interval = 5

  # Maximum sessions per user
  c.max_sessions_per_user = 100
end
```

## Manual Control

```ruby
session = Ask::Rails.agent_session(user: current_user, persist: false)
session.run("Analysis step 1")
session.save!  # Manual save

session.run("Analysis step 2")
session.save!
```

## Resuming Sessions

```ruby
# By session ID
session = Ask::Rails.resume(session_id)

# By user (most recent)
session = Ask::Rails.most_recent_session(user: current_user)

# List all sessions for a user
Ask::Rails.user_sessions(user: current_user).each do |s|
  puts "#{s.id}: #{s.turns} turns, last used #{s.last_used_at}"
end
```

## In-Memory vs Database

| | In-Memory | Database |
|---|---|---|
| **Setup** | None (default) | Run migration |
| **Performance** | Fastest | Fast with index |
| **Cross-request** | No | Yes |
| **Resumability** | No | Yes |
| **Inspectable** | No | Via Rails console |

## Next Steps

- [Use the database tools](/rails/database)
- [Set up error monitoring](/rails/errors)
- [Build custom agents](/extending/custom-agents)
