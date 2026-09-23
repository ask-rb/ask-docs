---
layout: default
title: Ask Permissions
parent: Core Components
nav_order: 19
---

# Ask Permissions

In this guide you will learn how the `ask-permissions` gem gates every tool
call before it runs. You will write `allow` / `ask` / `deny` rules, classify
calls with `PermissionRules#classify`, choose an `ApprovalPolicy` mode,
read tool metadata (`risk_level`, `side_effect_scope`, `always_ask`), and
resolve human approvals through `ApprovalQueue`.

By the end you will know what the host owns, what the safe defaults are,
and what the gem deliberately does *not* do.

The stack is three classes under `Ask::Permissions::*`:

| Class | Job |
|---|---|
| `PermissionRules` | Ordered `allow` / `ask` / `deny` patterns, evaluated on each call — never persisted |
| `ApprovalPolicy` | Mode-aware `before_tool` hook (`full_access` / `ask_before_changes` / `read_only`) that applies rules plus tool metadata |
| `ApprovalQueue` | Holds pending actions (`submit` / `pending_actions` / `approve` / `reject`) plus versioned `snapshot` / `restore_pending` |

{: .note }
> `PermissionRules`, `ApprovalPolicy`, and `ApprovalQueue` used to live under
> `Ask::Agent`. `ask-agent` depends on `ask-permissions` at runtime, so
> `approval:` sessions work without extra setup. Projects that reference
> these classes directly must also declare `gem "ask-permissions"`.

## 1. Install the gate

Add the gem and require it only when you build rules, policies, or queues
yourself. Passing `approval:` to a session pulls the stack in through
`ask-agent`.

<!-- docs-example: not-verified -->
```ruby
# Gemfile
gem "ask-permissions"
gem "ask-tools" # if you define Ask::Tool classes or use tool metadata
```

<!-- docs-example: not-verified -->
```ruby
require "ask-tools"
require "ask-permissions"
```

## 2. Write PermissionRules with allow / ask / deny

`PermissionRules` is an ordered list. You declare tool patterns and optional
argument patterns. First match wins when you call `#classify`.

Tool patterns accept an exact name (`"bash"`), a `Symbol` (`:bash`), a
`Regexp`, or `:all`. Argument patterns accept a `Regexp`, a substring, or
nothing at all (match any arguments). Hash arguments are matched as JSON.

<!-- docs-example: not-verified -->
```ruby
require "ask-permissions"

rules = Ask::Permissions::PermissionRules.new do |r|
  r.allow :bash, /git (status|log|diff)/
  r.ask   :bash, /rm -rf/
  r.deny  :write, %r{/\.env(\.local)?}
  r.ask   :destroy
end

rules.classify(:bash, { command: "git status" })
# => :allow — first rule matches, runs without asking

rules.classify(:bash, { command: "rm -rf /tmp/cache" })
# => :ask — queued for a human

rules.classify(:write, { path: "config/.env" })
# => :deny — blocked outright, never queued
```

What to remember:

* `:deny` blocks. `:ask` queues for a human. `:allow` proceeds.
* Rules are evaluated in declaration order. Put specific rules first.
* A call that matches no rule falls through to the policy default (see
  section 4). There is no implicit deny: an empty ruleset is an open door.
* Rules are never persisted. Build a new `PermissionRules` on boot from code
  you can review. The gem does not remember session or project grant choices
  for you.

Wire the rules into a session:

<!-- docs-example: not-verified -->
```ruby
require "ask-agent"

session = Ask::Agent::Session.new(
  model: "gpt-4o",
  tools: [Bash, Write, Destroy],
  approval: { rules: rules }
)

session.run("Check git status, then clean the cache")
# git status runs, rm -rf waits in session.approval_queue
```

## 3. Dangerous allows become asks by default

A universal `:allow` on a code-executing tool is too broad to be safe. If you
allow `bash`, `code`, `repl`, or `:all` without an argument pattern, the
ruleset rewrites that rule to `:ask` automatically. "Approve once" can never
silently become "approve anything".

<!-- docs-example: not-verified -->
```ruby
require "ask-permissions"

rules = Ask::Permissions::PermissionRules.new do |r|
  r.allow :bash # universal allow — converted to :ask
end

rules.classify(:bash, { command: "echo hello" })
# => :ask — the dangerous-allow guard rewrote it

rules.dangerous_rules
# => lists the rewritten rules so you can see what was caught
```

Opt out only when you mean it, for example in a throwaway sandbox:

<!-- docs-example: not-verified -->
```ruby
require "ask-permissions"

rules = Ask::Permissions::PermissionRules.new(auto_allow_dangerous: true) do |r|
  r.allow :bash
end

rules.classify(:bash, { command: "echo hello" })
# => :allow — you accepted the risk explicitly
```

{: .warning }
> Keep the default. Pass `auto_allow_dangerous: true` only in environments
> where arbitrary code execution is already expected, never for a user-facing
> agent.

## 4. Pick an ApprovalPolicy mode

`ApprovalPolicy` is the `before_tool` hook that sits between the model and
execution. It combines your `PermissionRules` with a coarse mode:

| Mode | Effect |
|---|---|
| `:full_access` | `:deny` rules still block and `:ask` rules still queue; otherwise calls proceed, including high-risk tools unless `always_ask` is set |
| `:ask_before_changes` | `:deny` blocks, `:ask` queues, and side-effecting or high/critical-risk tools queue unless an explicit `:allow` rule matches |
| `:read_only` | Tools with side effects are blocked; rules still apply to read-only calls |

<!-- docs-example: not-verified -->
```ruby
require "ask-permissions"

queue = Ask::Permissions::ApprovalQueue.new
policy = Ask::Permissions::ApprovalPolicy.new(
  queue: queue,
  rules: rules,
  tools: tool_registry,
  mode: :ask_before_changes
)

decision = policy.before_tool_call(tool_call, context)
case decision[:action]
when :proceed then executor.run(tool_call)
when :block   then executor.refuse(decision[:reason])
when :pending then executor.pause(tool_call, decision[:action_id])
end
```

When the reviewer responds, resolve by id through the queue (see section 6):

<!-- docs-example: not-verified -->
```ruby
queue.approve(decision[:action_id])
# or:
queue.reject(decision[:action_id])
```

Use the mode for the environment and the rules for the call. Production that
should never write is `:read_only`. Staging that may write with a human in
the loop is `:ask_before_changes`. See
[per-environment permissions](/ask-docs/rails/setup#per-environment-permissions)
for how the Rails harness sets `env.mode`.

## 5. Read tool metadata: risk, scope, and always_ask

Rules see the tool name and arguments. Metadata sees what kind of tool it is.
`ApprovalPolicy` consults both. Precedence matters: `:deny` and `:ask` rules
are handled first, then `always_ask`, then read-only side-effect blocking,
then an explicit `:allow` rule. The ordinary mode and risk checks apply after
those decisions.

Declare metadata on the tool:

<!-- docs-example: not-verified -->
```ruby
require "ask-tools"

class SendEmail < Ask::Tool
  risk_level :high          # or :critical for irreversible actions
  side_effect_scope :external
  always_ask true           # hard confirmation, never bypassed

  param :to, type: :string, desc: "Recipient", required: true
  param :body, type: :string, desc: "Message", required: true

  def execute(to:, body:)
    Ask::Result.ok(data: "Email sent to #{to}")
  end
end
```

What each field means:

* `risk_level` — `:high` or `:critical` marks a tool as changing something
  important. In `:ask_before_changes` mode these queue even without a
  matching `ask` rule. An explicit `:allow` rule can override this ordinary
  risk check; `always_ask` cannot be overridden. `:full_access` also bypasses
  the ordinary risk check.
* `side_effect_scope` — where the effect lands: `:none`, `:session`,
  `:workspace`, `:project`, `:system`, `:external`, or `:unknown`. Treat
  `:unknown` as side-effecting. Any scope other than `:none` queues under
  `:ask_before_changes` and blocks under `:read_only`, unless an earlier
  explicit `:ask`/`:deny` rule already decided the call. An explicit `:allow`
  rule bypasses the `:ask_before_changes` scope check, but not read-only mode.
* `always_ask` — hard confirmation. Even an `:allow` rule never bypasses it.
  Use it for irreversible or outward-facing tools (send email, publish,
  delete, charge, deploy).

<!-- docs-example: not-verified -->
```ruby
require "ask-permissions"

rules = Ask::Permissions::PermissionRules.new do |r|
  r.allow :send_email, /bob@example\.com/
end

# SendEmail has always_ask true, so the policy still queues it:
rules.classify(:send_email, { to: "bob@example.com" }) # => :allow
# ApprovalPolicy#before_tool_call returns :pending — always_ask wins
```

{: .note }
> If you remember one sentence: `allow` means "you may skip the queue",
> `always_ask` means "there is no queue-skipping for this tool".

## 6. Resolve the ApprovalQueue

The queue holds pending actions in process memory. You submit, list, approve,
or reject. The queue invokes its callback; the host decides how the approval
or rejection resumes the saved call.

<!-- docs-example: not-verified -->
```ruby
action_id = queue.submit(
  tool_call_id: "call_123",
  tool_name: "send_email",
  args: { to: "bob@example.com" },
  message: "Send this email?"
)
action = queue[action_id]
queue.pending_actions
# => [#<Action id: 1, tool_name: "send_email", args: {...}, status: :pending, ...>]

queue.approve(action_id) # => [resolved Action]; invokes on_approve(action)
# Instead of approving, reject the same still-pending action:
queue.reject(action_id)  # => [resolved Action]; invokes on_reject(action)
```

The queue itself does not execute tools. Its one-argument callbacks are where
the host resumes or refuses the saved tool call. In an `Ask::Agent::Session`,
the session wires those callbacks for you.

Through a session the same queue is exposed as `session.approval_queue`:

<!-- docs-example: not-verified -->
```ruby
session.approval_queue.pending_actions
session.approval_queue.approve(1) # or reject(1), not both
```

The agent never blocks on approval: the tool call resolves as pending, the
conversation continues, and the completed result re-enters the loop when you
approve.

### Snapshot and restore pending only

`snapshot` captures a versioned copy of pending actions. `restore_pending`
replaces the pending list with that copy. It restores data only: no callbacks
fire on restore, and decided actions (approved / rejected) are not carried
over.

<!-- docs-example: not-verified -->
```ruby
snapshot = queue.snapshot
# => { version: 1, next_id: 1, pending_actions: [...] }

restored_queue = Ask::Permissions::ApprovalQueue.new(
  on_approve: ->(action) { resume_saved_call(action) },
  on_reject: ->(action) { refuse_saved_call(action) }
)
restored_queue.restore_pending(snapshot)
# Restores into an empty queue; no on_submit / on_approve / on_reject fires.
```

Use snapshots to survive a host restart or to hand pending work to another
process. On restore, re-present each action in your review UI because the
original callbacks will not re-fire.

### Approval scopes in Ask Agent

The permissions queue records whether an explicit approval is `:once`,
`:session`, or `:project`. The queue does not apply those choices itself:
the host decides which scopes it supports. Ask Agent applies `:session` by
granting that whole tool for the current session; later matching calls skip
the ordinary approval queue. `:once` stays one-shot, and Ask Agent does not
turn `:project` into a session grant.

Ask Agent includes session grants in both `Session.persist!` / `Session.load`
and `SessionAdapter` snapshots / resume. Other hosts using
`ApprovalPolicy` directly must persist and restore
`SessionPermissionGrants#snapshot` themselves. The app-server offers only
`once` and `session` in `approval.required`; it rejects a `project` request
until it has a project-scoped store to honor it.

## 7. What the host owns

The gem classifies and queues. Your app executes, pauses, resumes, and
renders. Concretely, the host is responsible for:

* Adapting its call object to `before_tool_call(tool_call, context)` and
  honoring the three decisions: `:proceed`, `:block`, `:pending`.
* Storing suspended calls (`tool_call_id` / `action_id`) and resuming or
  refusing them after `approve` / `reject`.
* Building the review UI: who sees pending actions, in what order, with what
  argument preview and redaction.
* Persisting an audit trail. The queue is in-memory by design, so pair it
  with an append-only log (the `AuditLog` policy, or the
  [Rails audit log](/ask-docs/rails/setup#audit-log)) if you need a durable
  record of what was approved and what ran.
* Choosing `snapshot` discipline: when to snapshot, where to store the
  versioned payload, and how to re-present restored pending actions. A host
  that restores pending work must reconnect each action to its saved tool
  call; the queue snapshot alone cannot recreate host execution state.

## 8. Safe defaults checklist

Start here, then relax deliberately:

1. Mode `:ask_before_changes` unless the environment is explicitly full access
   or read-only.
2. Keep the dangerous-allow guard on. Do not pass
   `auto_allow_dangerous: true` in user-facing apps.
3. Add a `deny` rule for secrets first, for example
   `r.deny :write, %r{/\.env(\.local)?}` and `r.ask :bash, /rm -rf/`.
4. Mark tools that must always require a person with `always_ask true`.
   Use `risk_level :high` or `:critical` and an honest `side_effect_scope`
   to strengthen ordinary modes; remember that `:full_access` and an
   explicit `:allow` rule bypass ordinary risk checks.
   Remember `:unknown` means most restrictive.
5. Offer session/project scopes only when the host can apply and retain those
   grants; otherwise offer `once` only.
6. Resolve or snapshot pending approvals before shutdown. Accept that an
   unsnapshotted restart loses the queue.
7. Log every decision. Classification without an audit trail is not a safety
   story.

## 9. What permissions does not do

To avoid surprises, the gem deliberately does not:

* Persist rules or provide a project-grant store. There are no remembered
  `PermissionRules` to load later; rebuild them from reviewable code on every
  boot. `SessionPermissionGrants` holds whole-tool grants in memory and
  exposes a versioned snapshot. Ask Agent persists that snapshot as session
  state; hosts using the permissions gem directly must persist and restore it.
* Store project grants. The protocol can carry `once`, `session`, and
  `project` resolution choices, and the queue records the selected choice on
  its resolved `Action`; the host must decide which scopes it can honor and
  apply the matching grant. The gem has no project-grant backing store. This
  is distinct from a tool's `side_effect_scope`, which describes its impact
  rather than how long an approval lasts.
* Execute tools, pause sessions, or render UI. Those are host
  responsibilities (see section 7).

## More in this series

* [The Agent Loop](/ask-docs/core/agent) — how `approval:` sessions enqueue
  `:ask` calls and resume after `approve` / `reject`.
* [Tools and Execution](/ask-docs/core/tools) — declaring tools and their
  metadata (`risk_level`, `side_effect_scope`, `always_ask`).
* [Rails Setup — Per-Environment Permissions](/ask-docs/rails/setup#per-environment-permissions) — setting `env.mode` so each environment gets its own default.
* [Core Components](/ask-docs/core) — the full component index.

Next: build a small ruleset for your own tools, run it through `#classify`
with safe and dangerous arguments, and confirm the dangerous-allow guard and
`always_ask` behave as this guide describes before wiring it to a live agent.
