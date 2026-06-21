---
layout: default
title: Custom Service Gems
parent: Extending
nav_order: 4
---

# Custom Service Gems

Package a service integration as a Ruby gem. Follow the three-file pattern used by all ask-rb service gems.

## The Three-File Pattern

Every service gem has the same structure:

```
ask-my-service/
├── lib/
│   ├── ask/
│   │   └── my_service.rb      # Entry point
│   │   └── my_service/
│   │       ├── client.rb      # Authenticated client
│   │       └── errors.rb      # Structured error guide
│   └── ask-my_service.rb      # Require entry
├── ask-my_service.gemspec
└── README.md
```

## 1. Entry Point

`lib/ask/my_service.rb`:

```ruby
require "ask-auth"

module Ask
  module MyService
    GEM_NAME = "ask-my_service"
    DESCRIPTION = "MyService — what it does, simply stated"
    DOCS_URL = "https://docs.myservice.com/api"
    AUTH_NAME = :my_service_token
    AUTH_HOW = "Generate an API token at https://myservice.com/settings/tokens"
    QUICK_START = <<~RUBY
      client = Ask::MyService.client
      client.resource.list
    RUBY

    def self.client
      token = Ask::Auth.resolve(AUTH_NAME) or
        raise Ask::Auth::MissingCredential, "Set MY_SERVICE_TOKEN"

      ClientProxy.new(authenticated_client(token))
    rescue Ask::Auth::InvalidCredential => e
      raise e
    end
  end
end
```

## 2. Client

`lib/ask/my_service/client.rb`:

```ruby
require "faraday"

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
      rescue Faraday::ResourceNotFound => e
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

`lib/ask/my_service/errors.rb`:

```ruby
module Ask
  module MyService
    module Errors
      RATE_LIMIT = {
        authenticated: "100 requests per minute per token",
        error_status: 429
      }

      PAGINATION = {
        cursor_based: "MyService uses cursor-based pagination with 'after' and 'before' parameters"
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
          action: "Generate a new token and set it as MY_SERVICE_TOKEN"
        },
        "Faraday::ResourceNotFound" => {
          message: "The requested resource does not exist.",
          action: "Verify the resource identifier"
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

## 4. Require Entry

`lib/ask-my_service.rb`:

```ruby
require_relative "ask/my_service"
require_relative "ask/my_service/client"
require_relative "ask/my_service/errors"
```

## Using ask-auth

Your service gem uses `Ask::Auth.resolve(:my_service_token)` for credential resolution. The resolution chain works automatically:

1. **Environment variable** — `MY_SERVICE_TOKEN`
2. **Credentials file** — `~/.ask/credentials.yml`
3. **Rails credentials** — `Rails.application.credentials.my_service_token`

No additional auth configuration needed.

## Adding Skills to Your Gem

Add a `.ask/skills/` directory to your gem:

```
ask-my-service/
├── .ask/
│   └── skills/
│       └── my-service-workflow.md
```

The skill is auto-discovered when the gem is loaded.

## Testing with VCR

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
# Build
gem build ask-my_service.gemspec

# Push
gem push ask-my_service-0.1.0.gem
```

Follow the [ask-rb gem conventions](https://github.com/ask-rb) for naming, versioning, and metadata.

## Next Steps

- [Create custom skills for your gem](/extending/custom-skills)
- [Build a custom tool](/extending/custom-tools)
- [Learn about the service context pattern](/services/custom)
