---
layout: default
title: Persistence
parent: Rails Integration
nav_order: 3
---

# Persistence

Save and resume agent sessions using ActiveRecord. By default, sessions run
in-memory with no database needed. Wire up a persistence adapter when you want
to continue conversations across requests.

## How It Works

The persistence adapter stores sessions as rows in an `ask_sessions` table with
a JSONB `data` column that holds the full conversation state.

```ruby
# In-memory (default) — no database needed
session = Ask::Rails.agent_session

# Persisted — requires migration + adapter config
Ask::Rails.configure do |config|
  config.persistence_adapter = Ask::Rails::Persistence.new
end
session = Ask::Rails.agent_session
```

## Database Schema

Run the generator migration to create the table:

```bash
rails generate ask_rails:install
rails db:migrate
```

```ruby
create_table :ask_sessions do |t|
  t.string :session_id, null: false
  t.string :model
  t.jsonb :data, default: {}
  t.timestamps
end

add_index :ask_sessions, :session_id, unique: true
```

## Saving and Loading

```ruby
session = Ask::Rails.agent_session
session.run("Hello")

# The session ID is returned by the Session object
saved_id = session.id

# Load it later using the persistence adapter directly
adapter = Ask::Rails.configuration.persistence_adapter
data = adapter.load(saved_id)
```

## In-Memory vs Database

| | In-Memory | Database |
|---|---|---|
| **Setup** | None (default) | Run migration + configure adapter |
| **Cross-request** | No | Yes |
| **Resumability** | No | Yes |
| **Inspectable** | No | Via Rails console |

## Next Steps

- [Use the database tools](/ask-docs/rails/database)
- [Set up error monitoring](/ask-docs/rails/errors)
- [Build custom agents](/ask-docs/extending/custom-agents)
