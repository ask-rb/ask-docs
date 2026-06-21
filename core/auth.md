---
layout: default
title: Credential Resolution
parent: Core Components
nav_order: 7
---


# ask-auth

**Credential resolution for the ask-rb ecosystem.** A single API for resolving credentials
across all tools and service gems. Zero external dependencies.

```ruby
gem "ask-auth"
```

## Quick Start

```ruby
require "ask-auth"

# Simple — works everywhere, no config needed
token = Ask::Auth.resolve(:github_token)
# => "ghp_abc123..."

# With a user context (for per-user providers like Database)
token = Ask::Auth.resolve(:openai_api_key, user: current_user)
```

## Resolution Chain

By default, `resolve` walks providers in order and returns the first match:

| Order | Provider | Source |
|---|---|---|
| 1 | Env | Environment variables |
| 2 | File | `~/.ask/credentials.yml` |
| 3 | RailsCredentials | `Rails.application.credentials` |
| 4 | Database | ActiveRecord-backed token storage |
| 5 | OAuth | Interactive PKCE flow (deferred) |

## Configuration

```ruby
Ask::Auth.configure do |c|
  c.providers = [
    Ask::Auth::Providers::Env.new,
    Ask::Auth::Providers::File.new(path: "~/.myapp/creds.yml"),
    Ask::Auth::Providers::Database.new(model: AccessToken)
  ]
end
```

Once configured, the configuration is frozen and thread-safe.

## Providers

### Env

```ruby
Ask::Auth.resolve(:github_token)
# Checks: ENV["GITHUB_TOKEN"] → ENV["GITHUBTOKEN"] → ENV["github_token"]
```

No configuration needed.

### File

```yaml
# ~/.ask/credentials.yml
github_token: ghp_abc123...
openai_api_key: sk-...
```

```ruby
Ask::Auth::Providers::File.new
Ask::Auth::Providers::File.new(path: "~/.custom/credentials.yml")
```

File created with `0600` permissions on write.

### RailsCredentials

```ruby
Ask::Auth.resolve(:github_token)
# Looks up: Rails.application.credentials.github.token
```

Converts `snake_case` to dot-separated paths. Safely returns nil when Rails is not loaded.

### Database

Expects a model with `user_id`, `name`, `token`, `expires_at`, `refresh_token`.

```ruby
# app/models/credential.rb
class Credential < ApplicationRecord
  belongs_to :user
end

# config/initializers/auth.rb
Ask::Auth.configure do |c|
  c.providers = [
    Ask::Auth::Providers::Database.new
  ]
end
```

Automatically calls `refresh!` when a token has expired and a refresh token is available.

### OAuth

```ruby
provider = Ask::Auth::Providers::OAuth.new(
  client_id: "your-client-id",
  authorize_url: "https://provider.com/oauth/authorize",
  token_url: "https://provider.com/oauth/token"
)

# Step 1: Authorization URL
url = provider.authorize_url(user: current_user)
# Step 2: Exchange code for token
provider.authorize!(user: current_user, code: params[:code])
```

## Custom Providers

```ruby
Ask::Auth.configure do |c|
  c.providers = [
    Ask::Auth::Providers::Env.new,
    ->(name, user: nil) { user&.api_key_for(name) }
  ]
end
```

## Error Handling

```ruby
Ask::Auth::MissingCredential    # All providers returned nil
Ask::Auth::InvalidCredential    # Token rejected at usage time
```

## Implementation

- **Zero runtime dependencies** — uses only Ruby stdlib (`yaml`, `fileutils`, `openssl`)
- **Thread-safe** — configuration frozen after `configure`
- **Blank normalization** — empty/whitespace values treated as nil
- **No other ask-rb gems required** — independent of the tool/agent stack
