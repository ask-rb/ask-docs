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

schema = Ask::Schema.create do
  string :name, description: "The person's name"
  integer :age, description: "Their age"
  string :role, description: "Access level", enum: %w[admin user guest]
end

schema.new("person").to_json_schema
# => {name: "person",
#  description: nil,
#  schema:
#   {type: "object",
#    properties:
#     {name: {type: "string", description: "The person's name"},
#      age: {type: "integer", description: "Their age"},
#      role:
#       {type: "string",
#        enum: ["admin", "user", "guest"],
#        description: "Access level"}},
#    required: [:name, :age, :role],
#    additionalProperties: false,
#    strict: true}}
```

`Ask::Schema.create` returns a schema class. You instantiate it with a name (`schema.new("person")`) and call `to_json_schema` or `to_json` on the instance.

## Basic Types

```ruby
Ask::Schema.create do
  string  :name                          # string
  integer :count                         # integer
  number  :price, minimum: 0             # number (float)
  boolean :active                        # boolean
  string  :status, enum: %w[pending active]  # string with enum
  array   :tags, of: :string             # array of strings
  null    :deleted_at                    # nullable
end
```

Each type accepts the usual JSON Schema constraints as keywords: `minimum`, `maximum`, `pattern`, `format`, `min_length`, `max_length`, `min_items`, `max_items`, and so on.

## Nested Schemas

```ruby
require "ask-schema"

schema = Ask::Schema.create do
  string :title

  object :author do
    string :name
    string :email
  end

  array :comments do
    object do
      string :text
      string :author
    end
  end
end

schema.new("post").to_json_schema
# => {name: "post",
#  description: nil,
#  schema:
#   {type: "object",
#    properties:
#     {title: {type: "string"},
#      author:
#       {type: "object",
#        properties: {name: {type: "string"}, email: {type: "string"}},
#        required: [:name, :email],
#        additionalProperties: false},
#      comments:
#       {type: "array",
#        items:
#         {type: "object",
#          properties: {text: {type: "string"}, author: {type: "string"}},
#          required: [:text, :author],
#          additionalProperties: false}}},
#    required: [:title, :author, :comments],
#    additionalProperties: false,
#    strict: true}}
```

## Optional and Nullable Fields

By default, all fields are required. Make a field optional with `required: false`:

```ruby
require "ask-schema"

schema = Ask::Schema.create do
  string :name
  string :nickname, required: false
  integer :age, required: false
end

schema.new("person").to_json_schema
# => {name: "person",
#  description: nil,
#  schema:
#   {type: "object",
#    properties:
#     {name: {type: "string"},
#      nickname: {type: "string"},
#      age: {type: "integer"}},
#    required: [:name],
#    additionalProperties: false,
#    strict: true}}
```

Or allow null explicitly with `optional`:

```ruby
require "ask-schema"

schema = Ask::Schema.create do
  string :name
  optional :nickname do
    string
  end
end

schema.new("user").to_json_schema
# => {name: "user",
#  description: nil,
#  schema:
#   {type: "object",
#    properties:
#     {name: {type: "string"},
#      nickname: {anyOf: [{type: "string"}, {type: "null"}]}},
#    required: [:name, :nickname],
#    additionalProperties: false,
#    strict: true}}
```

## Reusable Definitions

`define` creates a named sub-schema; reference it with `of:` — the output gets proper `$defs` and `$ref`:

```ruby
require "ask-schema"

class User < Ask::Schema
  define(:address) do
    string :street
    string :city
    string :zip
  end

  string :name
  object :home_address, of: :address
  object :work_address, of: :address
end

User.properties[:home_address]
# => {"$ref" => "#/$defs/address"}
```

## Conditionals

Use `given` for if/then/else-style branches. Values coerce automatically: scalars become `const`, arrays become `enum`, regexps become `pattern`:

```ruby
require "ask-schema"

schema = Ask::Schema.create do
  integer :age
  string :country

  given(age: 18, country: "US") do
    requires :license_number
    validates :license_number, type: :string, pattern: /^[A-Z]{2}\d{6}$/
    otherwise do
      requires :country_name
    end
  end
end

json = schema.new("form").to_json_schema
json.dig(:schema, :if)
# => {properties: {"age" => {const: 18}, "country" => {const: "US"}}, required: ["age", "country"]}
json.dig(:schema, :then, :required)
# => ["license_number"]
json.dig(:schema, :else, :required)
# => ["country_name"]
```

`dependent` requires fields whenever another field is present:

```ruby
require "ask-schema"

schema = Ask::Schema.create do
  string :shipping_address
  dependent :shipping_address do
    requires :name, :street, :city
  end
end

schema.new("order").to_json_schema
# => {name: "order",
#  description: nil,
#  schema:
#   {type: "object",
#    properties: {shipping_address: {type: "string"}},
#    required: [:shipping_address],
#    additionalProperties: false,
#    strict: true,
#    dependentRequired: {"shipping_address" => ["name", "street", "city"]}}}
```

## Using with Tools

The schema DSL powers tool parameter definitions in `ask-tools`:

```ruby
require "ask-tools"

class SearchTool < Ask::Tool
  description "Search the knowledge base"

  param :query, type: :string, desc: "Search query", required: true
  param :limit, type: :integer, desc: "Max results", required: false

  def execute(query:, limit: 10)
    # ...
  end
end

SearchTool.params_schema
# => {type: "object",
#  properties:
#   {"query" => {type: "string", description: "Search query"},
#    "limit" => {type: "integer", description: "Max results"}},
#  required: ["query"],
#  additionalProperties: false}
```

Each `param` declaration generates a JSON Schema entry in `params_schema`.

## Using with Structured Output

Pass a schema to get structured JSON back from the LLM:

```ruby
schema = Ask::Schema.create do
  string :name
  integer :age
  array  :hobbies, of: :string
end

response = provider.chat(
  [{ role: "user", content: "Tell me about John, 28, who likes hiking and photography" }],
  model: "gpt-4o",
  schema: schema.new("person")
)

JSON.parse(response.content)
# => { "name" => "John", "age" => 28, "hobbies" => ["hiking", "photography"] }
```

Providers serialize the schema instance via `to_json_schema` into their own structured-output format.

## Validation

Schemas validate themselves at definition time. Circular references are detected and rejected:

```ruby
require "ask-schema"

schema = Ask::Schema.create { string :name }
schema.valid?     # => true
schema.validate!  # => nil
```

## Implementation

- **Zero dependencies** — pure Ruby, no JSON Schema gems required
- **Strict by default** — `strict true` and `additional_properties false` are the defaults; override per-class
- **Thread-safe** — stateless definition blocks
- **Standalone** — works without any other ask-rb gem

## Next Steps

- [Build a custom tool with parameters](/ask-docs/extending/custom-tools)
- [Use structured output with any provider](/ask-docs/core/providers)
- [Learn about tool execution](/ask-docs/core/tools)
