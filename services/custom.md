---
layout: default
title: Building a Service Gem
parent: Service Contexts
nav_order: 8
---

# Building a Service Gem

Create a service integration gem using the three-file pattern that all ask-rb service gems follow. This is the same pattern used by ask-github, ask-slack, ask-notion, and all other service gems.

## The Pattern

```
ask-my-service/
├── lib/
│   ├── ask/
│   │   └── my_service.rb              # Entry point
│   │   └── my_service/
│   │       ├── client.rb              # Authenticated API client
│   │       └── errors.rb              # Structured error knowledge
│   └── ask-my_service.rb              # Top-level require
├── ask-my_service.gemspec
└── README.md
```

## 1. Entry Point

The entry point defines constants for AI system prompts:

```ruby
# lib/ask/my_service.rb
require "ask-auth"

module Ask
  module MyService
    GEM_NAME = "ask-my_service"
    DESCRIPTION = "MyService — what it does"
    DOCS_URL = "https://docs.myservice.com/api"
    AUTH_NAME = :my_service_token
    AUTH_HOW = "Generate a token at https://myservice.com/settings"
    QUICK_START = <<~RUBY
      client = Ask::MyService.client
      # Use the client...
    RUBY

    def self.client
      token = Ask::Auth.resolve(AUTH_NAME) or
        raise Ask::Auth::MissingCredential, "Set #{AUTH_NAME.to_s.upcase}"
      ClientProxy.new(build_client(token))
    end

    def self.build_client(token)
      # Return the underlying HTTP client
    end
  end
end
```

## 2. Client

The client wraps the underlying HTTP client and provides consistent error handling:

```ruby
# lib/ask/my_service/client.rb
module Ask
  module MyService
    class ClientProxy
      def initialize(client)
        @client = client
      end

      def method_missing(name, *args, **kwargs, &block)
        @client.public_send(name, *args, **kwargs)
      rescue Faraday::UnauthorizedError
        raise Ask::Auth::InvalidCredential,
          "MyService token rejected. Generate a new one at #{AUTH_HOW}"
      rescue => e
        raise e
      end

      def respond_to_missing?(name, include_private = false)
        @client.respond_to?(name) || super
      end
    end
  end
end
```

## 3. Error Guide

The error module provides structured knowledge for AI agents:

```ruby
# lib/ask/my_service/errors.rb
module Ask
  module MyService
    module Errors
      RATE_LIMIT = {
        authenticated: "100 requests per minute per token",
        error_status: 429
      }

      PAGINATION = {
        cursor_based: "MyService uses cursor-based pagination with after/before"
      }

      HTTP_STATUS_CODES = {
        200 => "Success",
        401 => "Unauthorized — Token is missing, invalid, or revoked",
        404 => "Not Found — Resource does not exist",
        429 => "Too Many Requests — Rate limit exceeded"
      }.freeze

      ERROR_MAP = {
        "Faraday::UnauthorizedError" => {
          message: "The API token is missing, invalid, or has been revoked.",
          action: "Generate a new token at https://myservice.com/settings"
        }
      }.freeze

      def self.for(klass)
        ERROR_MAP[klass.to_s]
      end

      def self.status_code_description(code)
        msg = HTTP_STATUS_CODES[code]
        msg ? "HTTP #{code} — #{msg}" : nil
      end
    end
  end
end
```

## Conventions

Follow these conventions for consistency across the ecosystem:

| Convention | Standard |
|---|---|
| **Auth name** | `:my_service_token` (snake_case) |
| **Env variable** | `MY_SERVICE_TOKEN` (uppercase) |
| **DESCRIPTION** | "ServiceName — what it does in 5-10 words" |
| **GEM_NAME** | `"ask-my_service"` |
| **Error proxy** | Convert `UnauthorizedError` → `Ask::Auth::InvalidCredential` |
| **Retry config** | 3 retries, exponential backoff, 429/500/502/503 |
| **Gem dependency** | `ask-auth ~> 0.1` |

## Using ask-auth

Your gem gets credential resolution for free via `ask-auth`:

```yaml
# ~/.ask/credentials.yml
my_service_token: my-token-here
```

Or as an environment variable:

```bash
export MY_SERVICE_TOKEN="my-token-here"
```

Or in Rails credentials:

```yaml
my_service:
  token: my-token-here
```

## Adding Skills

Include a `.ask/skills/` directory in your gem for auto-discovered methodology:

```
ask-my-service/
├── .ask/
│   └── skills/
│       └── my-service-workflow.md
```

## Testing

```ruby
require "ask/test"

class MyServiceClientTest < Minitest::Test
  include Ask::Test::VCRHelper

  def test_list_resources
    VCR.use_cassette("my_service/resources") do
      client = Ask::MyService.client
      result = client.resources.list
      assert result.ok?
    end
  end
end
```

## Publishing

```bash
gem build ask-my_service.gemspec
gem push ask-my_service-0.1.0.gem
```

## Next Steps

- [Explore existing service gems](/ask-docs/services)
- [Build a custom tool](/ask-docs/extending/custom-tools)
- [Create custom skills](/ask-docs/extending/custom-skills)
