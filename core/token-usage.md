---
layout: default
title: Token Usage
parent: Core Components
nav_order: 17
---

# Token Usage

If you're building an AI product, you'll eventually need to answer a deceptively simple question: *how much did this cost us?*

Every LLM call burns tokens. Every document render takes work. Every API endpoint has a real cost behind it. If you charge for usage — or even if you just want to understand it — you need a way to measure, price, and track what your users consume.

That's what `ask-token-usage` does. It counts real tokens (via tiktoken), prices them at whatever rate you set, and gives each user a wallet with a balance, a ledger, and the ability to spend, grant, and adjust. It works anywhere Ruby runs. Pair it with `ask-token-usage-rails` for ActiveRecord persistence.

**Use ask-token-usage when** you want to track how many tokens your users consume, charge for usage, or just understand where your LLM budget is going. It's the accounting layer — billing sits on top.

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
gem "ask-token-usage-rails"
```

```sh
bundle install
rails g ask_token_usage:install
rails db:migrate
```

The generator creates two tables — `token_wallets` (one per user, with a cached balance) and `token_transactions` (an append-only ledger of every grant, spend, and adjustment).

## Setting a price

First, tell the gem what a token is worth to you. This is your internal rate — what you charge per token, or what a token costs you. You set it once, and everything derives from it:

```ruby
# config/initializers/ask_token_usage.rb
Ask::TokenUsage.configure do |c|
  c.price_per_token = 0.0001  # $0.0001 per token
end
```

Why `0.0001`? Because 1,000,000 tokens at that rate costs $100. You can set any rate — it's just a number the gem uses to convert between tokens and money.

Once set, you can query the price at any scale:

```ruby
Ask::TokenUsage.price_per_token   # => Money($0.0001)
Ask::TokenUsage.price_per(1_000)  # => Money($0.10)
Ask::TokenUsage.price_per(1_000_000)  # => Money($100.00)
```

This is useful for dashboards, invoices, top-up pages — anywhere you need to show what tokens cost in real currency.

## Giving users a wallet

In your model:

```ruby
class User < ApplicationRecord
  has_token_wallet
end
```

That's it. The user now has a `token_balance`, a transaction history, and the full wallet API:

```ruby
user.token_balance  # => 0

user.grant_tokens!(10_000, reason: :signup_bonus)
user.token_balance  # => 10_000
```

## Charging for things

The heart of it. Every action that costs tokens follows the same pattern: declare the cost, then spend.

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

`count_tokens` uses tiktoken under the hood — the same tokenizer OpenAI uses. It counts real tokens, not a guess.

### Spending

The key pattern: **charge only when the work succeeds**.

```ruby
user.spend_tokens_on!(:chat_message, input: "hi", output: "yo") do
  LLM.chat(messages: [...])
end
```

If the block raises — LLM timeout, API error, whatever — no tokens are deducted. The user isn't charged for failures. This is important: in the real world, LLM calls fail, and you don't want to bill for them.

If you just need a plain deduction (no block):

```ruby
user.deduct_tokens!(100, reason: :manual_adjustment)
```

### Checking before spending

Sometimes you want to check first, show a message, or offer a top-up:

```ruby
user.has_tokens_for?(1_000)                     # => true/false
user.sufficient_balance?(500)                    # => true/false

# Or estimate without spending:
Ask::TokenUsage.estimate(:chat_message, input: "hello", output: "world")
# => 6 (token count for the input + output)
```

## Granting tokens

Tokens enter the system through grants:

```ruby
user.grant_tokens!(10_000, reason: :trial)
user.grant_tokens!(5_000, reason: :referral, expires_at: 30.days.from_now)
```

The `expires_at` is optional. If you set it, the tokens expire — the sweep job removes them when the time comes.

## Monthly resets and rollover

This is a business decision, not a technical one. The gem gives you two primitives and lets you decide:

**Reset (no rollover):** Each billing cycle, set the balance to the allowance.

```ruby
user.adjust_balance_to!(plan.token_allowance, reason: :monthly_reset)
```

**Rollover:** Each cycle, add the allowance on top of whatever's left.

```ruby
user.grant_tokens!(plan.token_allowance, reason: :subscription_renewed)
```

Pick the one that fits your business model. The gem doesn't care.

## Expired tokens

If tokens should expire — trial bonuses, promotional credits — set an expiry when granting:

```ruby
user.grant_tokens!(10_000, reason: :trial, expires_at: 7.days.from_now)
```

The `SweepExpiredTokensJob` (shipped with ask-token-usage-rails) runs on a schedule and removes expired grants. Set it up in your job scheduler:

```yaml
# config/recurring.yml (Solid Queue)
ask_token_usage_sweep:
  class: Ask::TokenUsage::Rails::SweepExpiredTokensJob
  schedule: "every 1 hour"
```

## The ledger

Every grant, spend, and adjustment is recorded in an append-only ledger. You can't edit or delete these entries — they're the source of truth.

```ruby
user.token_transactions            # all entries, oldest first
user.token_transactions.debits     # just the spends
user.token_transactions.grants     # just the grants
user.token_transactions.since(30.days.ago)  # this month's activity
```

Each entry has a `kind` (grant, debit, adjustment, expiry), an `amount` (signed — positive for grants, negative for spends), a `reason`, and a `metadata` hash where you can stuff anything (model ID, provider, input/output token counts, etc.).

## Connecting to LLM calls

If you use ask-instrumentation, the gem can auto-deduct from every LLM call:

```ruby
require "ask/token_usage/instrumentation"

Ask::TokenUsage::Instrumentation.install do |payload|
  User.find_by(id: payload[:user_id])
end
```

Every `chat.ask` / `chat.stream.ask` event automatically deducts the measured token cost from the wallet. No manual wiring needed — just install the hook and it works.

## Billing integration

The gem is the accounting layer. It doesn't know about Stripe, PayPal, or any payment system. That's by design.

Your billing code calls `grant_tokens!` when the user buys tokens or subscribes:

```ruby
# Stripe webhook handler
workspace.grant_tokens!(10_000, reason: :top_up)

# Subscription renewal
workspace.grant_tokens!(plan.allowance, reason: :subscription_renewed)
```

This separation means you can swap payment providers without touching your token logic. The gem only knows about tokens in and tokens out.

## Callbacks

Want to send a Slack message when someone runs low on tokens? Fire a webhook when a large spend happens? Callbacks:

```ruby
Ask::TokenUsage.configure do |c|
  c.on_insufficient = ->(ctx) {
    AdminNotification.low_balance(user: ctx.owner, balance: ctx.previous_balance)
  }

  c.on_spend = ->(ctx) {
    Rails.logger.info "[Billing] #{ctx.owner} spent #{ctx.amount.abs} tokens: #{ctx.reason}"
  }
end
```

The callback receives a `CallbackContext` with the owner, event type, amount, reason, metadata, and the entry that was written.

## What about pricing models?

The gem handles the *measurement* side — counting tokens and tracking balances. Your pricing model (per-seat, per-token, freemium, tiered) lives in your billing code.

A common pattern:

```ruby
# Plan determines allowance
class Plan < ApplicationRecord
  def token_allowance
    details["token_allowance"].to_i
  end
end

# Billing code grants tokens on subscription
Pay::Subscription.include(Module.new {
  def after_subscription_active
    workspace.grant_tokens!(plan.token_allowance, reason: :subscription)
  end
})
```

The gem provides `grant!`, `deduct!`, `adjust_balance_to!`, and `spend!`. How you combine them is up to you.

## Pure Ruby, no Rails required

The core gem (`ask-token-usage`) works without Rails. Use it in scripts, background jobs, Sinatra apps, or anywhere:

```ruby
require "ask-token-usage"

Ask::TokenUsage.configure { |c| c.price_per_token = 0.0001 }

wallet = Ask::TokenUsage.wallet_for("user:42")
wallet.grant!(10_000, reason: :signup)
wallet.spend!(:chat_message, input: "hi") { "hello from the API" }
wallet.balance  # => 9_998
```

The in-memory store is built in. Swap it for ActiveRecord (via ask-token-usage-rails) when you need persistence.

## Next steps

- [Core Components](/ask-docs/core) — the full ask-rb ecosystem
- [The Agent Loop](/ask-docs/core/agent) — build AI agents with ask-agent
- [Web Fetch](/ask-docs/core/web-fetch) — URL to clean markdown
- [ask-token-usage on GitHub](https://github.com/ask-rb/ask-token-usage)
- [ask-token-usage-rails on GitHub](https://github.com/ask-rb/ask-token-usage-rails)
