---
layout: default
title: Token Usage
parent: Core Components
nav_order: 17
---

# Token Usage

If you're building an AI product, you'll eventually need to answer a deceptively simple question: *how much did this cost us?*

Every LLM call burns tokens. Every document render takes work. Every API endpoint has a real cost behind it. If you charge for usage — or even if you just want to understand it — you need a way to measure, price, and track what your users consume.

That's what `ask-token-usage` does. It counts real tokens (via tiktoken), prices them at whatever rate you set, and gives each user a wallet with a balance, a ledger, and the ability to spend, grant, and adjust.

**Use ask-token-usage when** you want to track how many tokens your users consume, charge for usage, or just understand where your LLM budget is going.

**Use ask-token-usage-rails when** you're in a Rails app and want wallets backed by ActiveRecord, a `has_token_wallet` concern, install generators, and an expiry sweep job.

## How it works

Think of it like a prepaid phone plan. Each user gets a wallet with a balance. Every action that costs something — an LLM call, a document render, a search query — deducts tokens from that wallet. You decide what things cost. The gem handles the math, the ledger, and the balance.

```
User does something          Gem counts tokens
that costs tokens     →      (tiktoken for text,
                              or you decide the number)
        │
        ▼
Wallet checks balance →  Enough? Deduct and do the thing.
                          Not enough? Raise InsufficientTokens.
```

## Installation

```ruby
# Gemfile
gem "ask-token-usage"
```

```sh
bundle install
```

That's all you need to get started. No generators, no migrations, no Rails required.

## Setting a price

First, tell the gem what a token is worth to you. This is your internal rate — what you charge per token, or what a token costs you. You set it once, and everything derives from it:

```ruby
Ask::TokenUsage.configure do |c|
  c.price_per_token = 0.0001  # $0.0001 per token
end
```

Why `0.0001`? Because 1,000,000 tokens at that rate costs $100. You can set any rate — it's just a number the gem uses to convert between tokens and money.

Once set, you can query the price at any scale:

```ruby
Ask::TokenUsage.price_per_token        # => Money($0.0001)
Ask::TokenUsage.price_per(1_000)       # => Money($0.10)
Ask::TokenUsage.price_per(1_000_000)   # => Money($100.00)
```

This is useful for dashboards, invoices, top-up pages — anywhere you need to show what tokens cost in real currency.

## Counting tokens

The gem wraps tiktoken — the same tokenizer OpenAI uses. Count real tokens in any text:

```ruby
Ask::TokenUsage.count_tokens("hello world")                # => 2
Ask::TokenUsage.count_tokens(text, model: "gpt-4o")        # model-aware encoding
```

This is how you turn a page of text, a chat message, or a document into a countable, billable number.

## Activities

Before you can spend tokens, you need to declare what things cost. An activity is a named action with a token price.

### Fixed costs

Some things always cost the same:

```ruby
Ask::TokenUsage.activity(:document_render, cost: 10)
Ask::TokenUsage.activity(:web_search, cost: 5)
```

### Dynamic costs

Some things depend on what's happening — like LLM calls where the cost depends on how many tokens were in the input and output:

```ruby
Ask::TokenUsage.activity(:chat_message) do |params|
  Ask::TokenUsage.count_tokens(params[:input]) +
    Ask::TokenUsage.count_tokens(params[:output])
end
```

### Estimating cost

You can check what an activity would cost without spending anything:

```ruby
Ask::TokenUsage.estimate(:chat_message, input: "hello", output: "world")
# => 6
```

## The wallet

A wallet is where tokens live. It has a balance, a history, and methods to spend and grant.

### Creating a wallet

Wallets are keyed by an owner — any identifier you choose:

```ruby
wallet = Ask::TokenUsage.wallet_for("user:42")
```

In plain Ruby, the owner can be a string, an ID, or any object. The gem doesn't care — it just uses it as a key.

### Granting tokens

Tokens enter the system through grants:

```ruby
wallet.grant!(10_000, reason: :signup_bonus)
wallet.grant!(5_000, reason: :referral, expires_at: 30.days.from_now)
```

The `expires_at` is optional. If you set it, the tokens will expire.

### Checking balance

```ruby
wallet.balance    # => 15_000
wallet.has?(1_000)  # => true
```

### Spending tokens

The key pattern: **charge only when the work succeeds**.

```ruby
wallet.spend!(:chat_message, input: "hi", output: "yo") do
  LLM.chat(messages: [...])
end
```

If the block raises — LLM timeout, API error, whatever — no tokens are deducted. The user isn't charged for failures.

If you just need a plain deduction:

```ruby
wallet.deduct!(100, reason: :manual_adjustment)
```

### Adjusting balance

Sometimes you need to set an exact balance — monthly resets, corrections, admin overrides:

```ruby
wallet.adjust_balance_to!(0, reason: :monthly_reset)
wallet.adjust_balance_to!(50_000, reason: :admin_correction)
```

This records an adjustment entry in the ledger showing the delta.

### Transaction history

Every grant, spend, and adjustment is recorded in an append-only ledger. You can't edit or delete these entries — they're the source of truth.

```ruby
wallet.entries                    # all entries, oldest first
wallet.entries(kind: :debit)     # just the spends
wallet.entries(kind: :grant)     # just the grants
wallet.used_since(30.days.ago)   # total spent this month
```

Each entry has a `kind`, `amount` (signed), `reason`, `metadata` hash, and timestamps.

## Callbacks

Want to send a Slack message when someone runs low on tokens? Fire a webhook when a large spend happens? Callbacks:

```ruby
Ask::TokenUsage.configure do |c|
  c.on_insufficient = ->(ctx) {
    puts "#{ctx.owner} needs more tokens (has #{ctx.previous_balance})"
  }

  c.on_spend = ->(ctx) {
    puts "#{ctx.owner} spent #{ctx.amount.abs} tokens: #{ctx.reason}"
  }
end
```

The callback receives a `CallbackContext` with the owner, event type, amount, reason, and the entry that was written.

## Pricing models

The gem handles the *measurement* side — counting tokens and tracking balances. Your pricing model (per-seat, per-token, freemium, tiered) lives in your code.

A common pattern — each billing cycle, set the balance to the allowance:

```ruby
wallet.adjust_balance_to!(plan.token_allowance, reason: :monthly_reset)
```

Or add the allowance on top (rollover):

```ruby
wallet.grant!(plan.token_allowance, reason: :subscription_renewed)
```

Pick the one that fits your business. The gem doesn't care.

## Billing integration

The gem is the accounting layer. It doesn't know about Stripe, PayPal, or any payment system. That's by design.

Your billing code calls `grant!` when the user buys tokens or subscribes. The gem just tracks what goes in and out.

## Pure Ruby

The core gem works without Rails. Use it in scripts, background jobs, Sinatra apps, or anywhere:

```ruby
require "ask-token-usage"

Ask::TokenUsage.configure { |c| c.price_per_token = 0.0001 }

wallet = Ask::TokenUsage.wallet_for("user:42")
wallet.grant!(10_000, reason: :signup)
wallet.spend!(:chat_message, input: "hi") { "hello from the API" }
wallet.balance  # => 9_998
```

An in-memory store is built in. It's perfect for scripts, tests, and demos.

---

## Rails

If you're in a Rails app, `ask-token-usage-rails` adds ActiveRecord persistence on top of the core gem. Wallets are backed by database rows, transactions are real records, and you get a generator to set it all up.

### Installation

```ruby
# Gemfile
gem "ask-token-usage-rails"
```

```sh
bundle install
rails g ask_token_usage:install
rails db:migrate
```

The generator creates two tables:

- **token_wallets** — one row per user, with a cached balance and a polymorphic owner reference
- **token_transactions** — the append-only ledger (every grant, spend, adjustment, and expiry)

### Adding a wallet to a model

```ruby
class User < ApplicationRecord
  has_token_wallet
end
```

This adds:

```ruby
user.token_balance                                   # current balance
user.grant_tokens!(10_000, reason: :trial)           # add tokens
user.deduct_tokens!(500, reason: :render)             # remove tokens
user.spend_tokens_on!(:chat_message, input: "hi") { LLM.chat(...) }  # spend on success
user.has_tokens_for?(1_000)                           # check balance
user.token_usage_since(30.days.ago)                   # usage report
user.token_transactions                               # AR scope for the ledger
```

All the same wallet methods from the core gem — just accessible as model methods.

### Connecting to LLM calls

If you use ask-instrumentation, the gem can auto-deduct from every LLM call:

```ruby
# config/initializers/ask_token_usage.rb
require "ask/token_usage/instrumentation"

Ask::TokenUsage::Instrumentation.install do |payload|
  User.find_by(id: payload[:user_id])
end
```

Every `chat.ask` / `chat.stream.ask` event automatically deducts the measured token cost from the wallet. No manual wiring needed.

### Expired tokens

If tokens should expire — trial bonuses, promotional credits — set an expiry when granting:

```ruby
user.grant_tokens!(10_000, reason: :trial, expires_at: 7.days.from_now)
```

The `SweepExpiredTokensJob` runs on a schedule and removes expired grants:

```yaml
# config/recurring.yml (Solid Queue)
ask_token_usage_sweep:
  class: Ask::TokenUsage::Rails::SweepExpiredTokensJob
  schedule: "every 1 hour"
```

### What the generator creates

```ruby
# Migration
create_table :token_wallets do |t|
  t.string :owner_type, null: false
  t.bigint :owner_id, null: false
  t.bigint :balance, null: false, default: 0
  t.timestamps
end
add_index :token_wallets, [:owner_type, :owner_id], unique: true

create_table :token_transactions do |t|
  t.references :token_wallet, null: false, foreign_key: true
  t.string :entry_type, null: false
  t.bigint :amount, null: false
  t.string :reason, null: false
  t.json :metadata, null: false, default: {}
  t.bigint :balance, null: false
  t.datetime :expires_at
  t.datetime :created_at, null: false
end
```

## Next steps

- [Core Components](/ask-docs/core) — the full ask-rb ecosystem
- [The Agent Loop](/ask-docs/core/agent) — build AI agents with ask-agent
- [Web Fetch](/ask-docs/core/web-fetch) — URL to clean markdown
- [ask-token-usage on GitHub](https://github.com/ask-rb/ask-token-usage)
- [ask-token-usage-rails on GitHub](https://github.com/ask-rb/ask-token-usage-rails)
