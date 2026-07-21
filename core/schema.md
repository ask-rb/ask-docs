---
layout: default
title: Schema & Structured Output
parent: Core Components
nav_order: 6
---

# Schema & Structured Output

**JSON Schema DSL for the ask-rb ecosystem.** Used by tool parameters AND structured LLM output. Zero external dependencies.

```ruby
gem "ask-schema"
```

## Quick Start

```ruby
require "ask-schema"

schema = Ask::Schema.define do
  string :name, desc: "The person's name"
  integer :age, desc: "Their age"
  enum :role, %w[admin user guest], desc: "Access level"
end

schema.to_json_schema
# => {
#   type: "object",
#   properties: {
#     name: { type: "string", description: "The person's name" },
#     age: { type: "integer", description: "Their age" },
#     role: { type: "string", enum: ["admin", "user", "guest"] }
#   },
#   required: ["name", "age", "role"]
# }
```

## Basic Types

```ruby
Ask::Schema.define do
  string  :name                          # string
  integer :count                         # integer
  number  :price                         # number (float)
  boolean :active                        # boolean
  enum    :status, %w[pending active]    # string with enum
  array   :tags, type: :string           # array of strings
end
```

## Nested Schemas

```ruby
Ask::Schema.define do
  string :title

  object :author do
    string :name
    string :email
  end

  array :comments, type: :object do
    string :text
    string :author
  end
end
```

## Optional Fields

By default, all fields are required. Make a field optional:

```ruby
Ask::Schema.define do
  string :name
  string :nickname, required: false
  integer :age, required: false
end
```

## Using with Tools

The schema DSL powers tool parameter definitions:

```ruby
class SearchTool < Ask::Tool
  description "Search the knowledge base"

  param :query, type: :string, desc: "Search query", required: true
  param :limit, type: :integer, desc: "Max results", required: false

  def execute(query:, limit: 10)
    # ...
  end
end
```

Each `param` declaration generates a JSON Schema entry in `params_schema`.

## Using with Structured Output

Pass a schema to get structured JSON back from the LLM:

```ruby
schema = Ask::Schema.define do
  string :name
  integer :age
  array  :hobbies, type: :string
end

response = provider.chat(
  [{ role: "user", content: "Tell me about John, 28, who likes hiking and photography" }],
  model: "gpt-4o",
  schema: schema
)

JSON.parse(response.content)
# => { "name" => "John", "age" => 28, "hobbies" => ["hiking", "photography"] }
```

## Conditional Schemas

Use `oneOf` for conditional fields:

```ruby
Ask::Schema.define do
  string :type, enum: ["user", "admin"]

  # Branch based on type
  object :details do
    oneOf do
      schema do
        string :department  # for admins
      end
      schema do
        string :subscription_tier  # for users
      end
    end
  end
end
```

## Implementation

- **Zero dependencies** — pure Ruby, no JSON Schema gems required
- **Immutable definitions** — schemas are frozen after construction
- **Thread-safe** — stateless definition blocks
- **Standalone** — works without any other ask-rb gem

## Next Steps

- [Build a custom tool with parameters](/ask-docs/extending/custom-tools)
- [Use structured output with any provider](/ask-docs/core/providers)
- [Learn about tool execution](/ask-docs/core/tools)
