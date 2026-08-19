---
layout: default
title: Token Usage
parent: Core Components
nav_order: 17
---

# Token Usage

Token-based usage tracking for Rails applications. Count real tokens with tiktoken, price them per million, declare activity costs, and run a wallet/ledger engine against a pluggable store.

Two gems, clean separation:

| Gem | Purpose |
|---|---|
| [`ask-token-usage`](https://github.com/ask-rb/ask-token-usage) | Pure Ruby — counting, pricing, activities, wallet engine, ledger |
| [`ask-token-usage-rails`](https://github.com/ask-rb/ask-token-usage-rails) | ActiveRecord store, `has_token_wallet`, generator, sweep job |

## Quick start

```ruby
# Gemfile
gem "ask-token-usage", "~> 0.1.0"
gem "ask-token-usage-rails", "~> 0.1.0"
```

```ruby
# config/initializers/ask_token_usage.rb
Ask::TokenUsage.configure do |c|
  c.price_per_token = 0.0001  # $0.0001 per token ($100 per 1M)
end
```

```ruby
# Migration
rails g ask_token_usage:install
rails db:migrate
```

```ruby
class User < ApplicationRecord
  has_token_wallet
end

user.grant_tokens!(10_000, reason: :trial, expires_at: 7.days.from_now)
user.spend_tokens_on!(:chat_message, input: "hi", output: "yo") { LLM.chat(...) }
user.token_balance  # => 9_998
```

## Architecture

```
┌─────────────────────────────────────────────────┐
│  Your app (controllers, jobs, agents)           │
└───────────────────┬─────────────────────────────┘
                    │
┌───────────────────▼─────────────────────────────┐
│  ask-token-usage (pure Ruby)                    │
│  ─────────────────────────────                  │
│  Counting (tiktoken) · Pricing (Money)          │
│  Activities · Wallet engine · LedgerEntry       │
└───────────────────┬─────────────────────────────┘
                    │ Store port
        ┌───────────┴───────────┐
        │                       │
  ┌─────▼─────┐         ┌──────▼──────┐
  │  Memory   │         │ ActiveRecord│
  │  Store    │         │    Store    │
  │ (scripts, │         │ (Rails app) │
  │  tests)   │         └─────────────┘
  └───────────┘
```

The wallet engine never touches a database. It talks to a 4-method Store port. The Rails gem provides the ActiveRecord implementation; the core ships an in-memory one.

## Token counting

Wrap tiktoken_ruby — count real tokens in any text:

```ruby
Ask::TokenUsage.count_tokens("hello world")               # => 2
Ask::TokenUsage.count_tokens(text, model: "gpt-4o")       # model-aware encoding
```

## Pricing

Set once, query at any scale:

```ruby
Ask::TokenUsage.configure { |c| c.price_per_token = 0.0001 }

Ask::TokenUsage.price_per_token         # => Money($0.0001)
Ask::TokenUsage.price_per(1_000)        # => Money($0.10)
Ask::TokenUsage.price_per(1_000_000)    # => Money($100.00)
Ask::TokenUsage.tokens_for(10)          # => 100_000  ($10 worth)
Ask::TokenUsage.cents_for(1_000)        # => 10
```

## Activities

Declare what costs what — fixed or dynamic:

```ruby
Ask::TokenUsage.activity(:chat_message) do |params|
  Ask::TokenUsage.count_tokens(params[:input]) +
    Ask::TokenUsage.count_tokens(params[:output])
end

Ask::TokenUsage.activity(:document_render, cost: 10)

Ask::TokenUsage.estimate(:chat_message, input: "hi", output: "yo")  # => 4
```

## Wallet

The core engine — grant, deduct, spend, adjust:

```ruby
wallet = Ask::TokenUsage.wallet_for(owner)

wallet.grant!(10_000, reason: :trial, expires_at: 7.days.from_now)
wallet.deduct!(500, reason: :render)
wallet.spend!(:chat_message, input: "hi") { LLM.chat(...) }  # only charges on success
wallet.adjust_balance_to!(0, reason: :monthly_reset)           # set exact balance

wallet.balance          # => 9_500
wallet.has?(1_000)      # => true
wallet.entries          # immutable ledger
wallet.used_since(30.days.ago)
```

## ActiveRecord (Rails)

The `has_token_wallet` concern adds the full API to any model:

```ruby
class User < ApplicationRecord
  has_token_wallet
end

user.token_balance
user.grant_tokens!(10_000, reason: :trial)
user.deduct_tokens!(500, reason: :render)
user.spend_tokens_on!(:chat_message, input: "hi") { LLM.chat(...) }
user.token_transactions  # AR scope for the ledger
```

Tables created by the generator:

- `token_wallets` — polymorphic owner + cached balance
- `token_transactions` — append-only ledger (immutable, indexed)

## Expiry

Grants can expire. The Rails gem ships a sweep job:

```ruby
wallet.grant!(10_000, reason: :trial, expires_at: 7.days.from_now)

# Schedule the sweep job (Solid Queue)
# config/recurring.yml
ask_token_usage_sweep:
  class: Ask::TokenUsage::Rails::SweepExpiredTokensJob
  schedule: "every 1 hour"
```

## Callbacks

```ruby
Ask::TokenUsage.configure do |c|
  c.on_grant       = ->(ctx) { puts "Granted #{ctx.amount} to #{ctx.owner}" }
  c.on_spend       = ->(ctx) { puts "Spent #{ctx.amount.abs} from #{ctx.owner}" }
  c.on_adjust      = ->(ctx) { puts "Adjusted #{ctx.owner} to #{ctx.new_balance}" }
  c.on_insufficient = ->(ctx) { puts "Insufficient: need #{ctx.amount}, have #{ctx.previous_balance}" }
end
```

## Instrumentation bridge

Auto-deduct from ask-instrumentation LLM events (opt-in):

```ruby
require "ask/token_usage/instrumentation"
Ask::TokenUsage::Instrumentation.install do |payload|
  User.find_by(id: payload[:workspace_id])
end
```

Every `chat.ask` / `chat.stream.ask` event automatically deducts the measured token cost from the wallet.

## Billing integration

The gem is the **accounting layer**. Billing sits on top:

```ruby
# Stripe webhook
workspace.grant_tokens!(10_000, reason: :top_up)

# Subscription renewal
workspace.grant_tokens!(plan.allowance, reason: :subscription_renewal)

# Monthly reset
workspace.adjust_balance_to!(plan.allowance, reason: :monthly_reset)
```

No Stripe, no `pay` gem dependency. Your billing code calls `grant_tokens!` — the gem doesn't care how tokens get into the wallet.

## Next steps

- [Core Components](/ask-docs/core) — full list of ask-rb gems
- [Web Fetch](/ask-docs/core/web-fetch) — URL → clean markdown
- [Web Search](/ask-docs/core/web-search) — local SearXNG-backed search
- [ask-token-usage on GitHub](https://github.com/ask-rb/ask-token-usage)
- [ask-token-usage-rails on GitHub](https://github.com/ask-rb/ask-token-usage-rails)
