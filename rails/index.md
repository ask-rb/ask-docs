---
layout: default
title: ask-rails
nav_order: 4
---

# ask-rails

Rails integration for the ask-rb ecosystem. The only gem a Rails app needs to join the ask-rb stack.

## Installation

```ruby
gem "ask-rails"
rails generate ask_rails:install
```

## Components

- **Railtie** — Configures RubyLLM, discovers tools and service gems on boot
- **Persistence** — ActiveRecord adapter for session persistence
- **Session Factory** — `Ask::Rails.agent_session` creates a pre-configured agent
- **Service Discovery** — Auto-discovers installed `ask-*` gems
- **Generators** — Migration + initializer + `app/tools/`
- **Rails Tools** — ReadFile, RunCommand, SearchCodebase, ReadRoutes

## Quick Start

```ruby
session = Ask::Rails.agent_session
response = session.run("What models do we have?")
```
