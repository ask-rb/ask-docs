---
layout: default
title: Ask Permissions
parent: Core Components
nav_order: 19
---

# Ask Permissions

Tools run whatever the model hands them. ask-permissions is the gate in front
of that: every tool call is classified before it executes — allowed through,
queued for a human, or denied outright. It backs the human-in-the-loop
approval flow in the [agent loop](/ask-docs/core/agent) and the coarse access
modes (`:full_access`, `:read_only`, `:ask_before_changes`) the Rails and
Ruby harnesses set per environment.

The stack is three classes in the **ask-permissions** gem, all under
`Ask::Permissions::*`:

| Class | Job |
|---|---|
| `PermissionRules` | Persisted `allow` / `ask` / `deny` patterns — "approve once, remember the pattern" |
| `ApprovalQueue` | Holds pending actions until a human drains them |
| `ApprovalPolicy` | The `before_tool` hook that applies the rules and enqueues what needs review |

{: .note }
> `PermissionRules`, `ApprovalPolicy`, and `ApprovalQueue` used to live under
> `Ask::Agent`. ask-agent depends on ask-permissions at runtime, so
> `approval:` sessions work without extra setup; projects that reference
> these classes directly must also declare `gem "ask-permissions"`.

## Installation

```ruby
# Gemfile
gem "ask-permissions"
```

```ruby
require "ask-permissions"
```

The require is only needed when you build rules, queues, or policies
yourself — passing `approval:` to a session pulls the stack in through
ask-agent.

## Setting up rules and an approval policy

Declare which tools deserve a human gate, write down the patterns you want
remembered, and hand both to the session:

```ruby
# ask-tools
class SendEmail < Ask::Tool
  approval_required true
  param :to, type: :string, desc: "Recipient", required: true
  param :body, type: :string, desc: "Message", required: true

  def execute(to:, body:)
    Ask::Result.ok(data: "Email sent to #{to}")
  end
end

# ask-permissions
rules = Ask::Permissions::PermissionRules.new do |r|
  r.allow :bash, /^git (pull|push|status)/   # these run without asking
  r.ask   :bash, /^rm -rf/                   # always prompt for destructive
  r.deny  :write, %r{/\.env(\.local)?$}      # never touch secrets
  r.ask   :destroy, :all
end

session = Ask::Agent::Session.new(
  model: "gpt-4o",
  tools: [Bash, Write, Destroy, SendEmail],
  approval: { rules: rules }
)

session.run("Email bob about the launch")
```

The session wires an `ApprovalPolicy` over your rules and its own
`ApprovalQueue`. Calls classified `:ask` land in the queue; the session
keeps running and you resolve them whenever you are ready.

If you do not need remembered patterns, the simpler option shapes still work:

```ruby
Ask::Agent::Session.new(model: "gpt-4o", tools: [SendEmail], approval: true)

Ask::Agent::Session.new(
  model: "gpt-4o",
  tools: [SendEmail, Ping],
  approval: {
    require_approval: ["destroy", /^admin_/],  # extra tools to gate
    auto_approve: { "ping" => true }           # user-enabled auto-approval
  }
)
```

### How rules match

- **Tool patterns**: exact name (`"bash"`), `Symbol`, `Regexp`, or `:all`.
  **Argument patterns**: `Regexp`, substring, or omitted for any arguments
  (hashes are matched as JSON). First matching rule wins, in declaration
  order.
- Rules take precedence over tool declarations: `:deny` blocks outright,
  `:allow` proceeds without the queue (even for `approval_required` tools),
  and `:ask` queues regardless of `auto_approvable`.

## Using ApprovalPolicy standalone

For full control, drop the policy on the hook seam yourself — the session's
`approval:` option is only sugar over the same wiring:

```ruby
queue = Ask::Permissions::ApprovalQueue.new
policy = Ask::Permissions::ApprovalPolicy.new(
  queue: queue, tools: [SendEmail], require_approval: :all
)
session = Ask::Agent::Session.new(
  model: "gpt-4o",
  tools: [SendEmail],
  hooks: { before_tool: [policy.method(:before_tool_call)] }
)
```

The approval queue, the `:pending` result status, and the `approval:` option
are core Session mechanisms; `ApprovalPolicy` is the reference classification
policy that runs on top of them.

## Resolving the queue

```ruby
session.approval_queue.pending_actions   # [{id: 1, tool_name: "send_email", ...}]
session.approval_queue.approve(1)        # executes the tool, feeds result back
session.approval_queue.reject(1)         # injects "rejected by the user"
session.approval_queue.approve_all
session.approval_queue.reject_all
```

- **Approving** executes the real tool call and the follow-up turn voices the
  outcome. **Rejecting** injects a "rejected by the user" message and the
  agent adapts. A failed apply leaves the action pending for retry.
- The agent never blocks on approval: the tool call resolves as
  `Ask::Result.pending`, the conversation continues, and the completed result
  re-enters the loop through `register_pending_tool` →
  `complete_pending_tool`.
- **Auto-approval is a dual signal**: a tool marked `auto_approvable true`
  AND a user rule enabling it (`auto_approve: { "tool_name" => true }`).
  Nothing is silently applied past a manual gate — eligible actions drain in
  id order with a single-flight guard, so no action applies twice.

## Security caveats

{: .warning }
> The gate is only as strong as the rules you write. Three behaviors to
> know before you trust it.

### A dangerous `:allow` is downgraded to `:ask`

An unrestricted `:allow` on a code-executing tool (`bash`, `code`, `repl`,
or `:all`) is downgraded to `:ask` — so "approve once" can't become
"approve anything". `rules.dangerous_rules` lists what the guard caught.
Only opt out deliberately:
`Ask::Permissions::PermissionRules.new(auto_allow_dangerous: true) { ... }`.

### Rules default to allow

Rules only act where they match. A call that matches no rule falls through
to the session's baseline approval behavior — tools without
`approval_required`, outside every `require_approval` pattern, run
immediately. There is no implicit deny: an empty ruleset is an open door
(the guard above only rewrites `:allow` rules that already exist). Write
rules for what must be gated or blocked; never rely on "I did not allow it"
to mean "it cannot run."

### The queue is in-memory

`ApprovalQueue` holds pending actions in process memory. Restart the process
and they are gone; a second process cannot see or drain them. Drain the
queue — or accept losing pending approvals — before shutdown, and pair it
with an append-only audit trail (the `AuditLog` policy, or the
[Rails audit log](/ask-docs/rails/setup#audit-log)) if you need a durable
record of what was approved and what ran.

## Permissions gate vs ApprovalPolicy

ask-agent also ships a much simpler gate under `Ask::Agent::Policies`:
**Permissions**. Where `ApprovalPolicy` classifies individual calls, the
Permissions gate only asks which mode the environment is in:

| Mode | Effect |
|---|---|
| `:full_access` | All tools allowed, no approval needed |
| `:read_only` | Write/edit/bash/destroy tools blocked |
| `:ask_before_changes` | Write/edit/bash/destroy require approval |

- **Permissions gate** — pick a mode and every tool call is checked against
  it: no argument patterns, no memory of past decisions. This is the policy
  `agent_session` creates automatically when a harness sets `env.mode` (see
  [per-environment permissions](/ask-docs/rails/setup#per-environment-permissions)).
- **ApprovalPolicy** — classifies each call by pattern: `:deny` blocks,
  `:ask` enqueues, `:allow` passes, plus `require_approval` patterns and the
  auto-approval dual signal. Reach for it when the decision depends on which
  tool and which arguments — "always ask for `rm -rf`, never ask for
  `git status`, never touch `.env`."

Choose the gate when policy is a property of the environment (production is
read-only). Choose `ApprovalPolicy` when policy is a property of the call.
Both sit on the same `before_tool` seam — run either, replace either, or
write your own with the same signature.
